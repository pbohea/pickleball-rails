class VideoAnalysisJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)
    analysis = nil
    video.update!(status: :processing)

    raise "Missing original video" unless video.original_video.attached?

    desc = video.notes.to_s.strip
    raise "Missing target description (notes)" if desc.blank?

    analysis = video.analyses.create!(
      status: :running,
      started_at: Time.current,
      model_version: "ready-score-v1",
      cv_results: {}
    )

    analysis.analysis_events.create!(
      event_type: "analysis_started",
      payload: { message: "Cloud Run analysis started" },
      timestamp_ms: (Time.current.to_f * 1000).to_i
    )

    input_uri = ensure_gcs_input(video)
    output_uri = build_output_uri(video, analysis)

    client = Gcp::CloudRunJobsClient.new(
      project: ENV.fetch("GCP_PROJECT"),
      region: ENV.fetch("GCP_REGION", "us-central1")
    )

    args = [
      "--video=#{input_uri}",
      "--desc=#{desc}",
      "--start=00:00:00",
      "--output=#{output_uri}"
    ]

    execution_name = client.run_job(ENV.fetch("PICKLEBALL_JOB_NAME"), args: args)

    analysis.update!(
      cv_results: {
        "execution_name" => execution_name,
        "output_uri" => output_uri,
        "input_uri" => input_uri,
        "desc" => desc,
        "poll_attempts" => 0
      }
    )

    VideoAnalysisPollJob.set(wait: 30.seconds).perform_later(analysis.id)
  rescue StandardError => e
    video&.update(status: :failed)
    analysis&.update(status: :failed)
    Rails.logger.error("VideoAnalysisJob failed for video #{video_id}: #{e.class} #{e.message}")
    raise
  end

  private

  def ensure_gcs_input(video)
    bucket = ENV.fetch("GCS_BUCKET")
    service = video.original_video.blob.service
    if service.class.name.include?("GCSService")
      return "gs://#{bucket}/#{video.original_video.key}"
    end

    storage = Gcp::StorageClient.new(bucket_name: bucket)
    filename = video.original_video.filename.to_s
    dest_path = "pickleball/inputs/video_#{video.id}_#{Time.current.to_i}_#{filename}"
    video.original_video.blob.open do |file|
      return storage.upload_io(file, dest_path, content_type: video.original_video.blob.content_type)
    end
  end

  def build_output_uri(video, analysis)
    bucket = ENV.fetch("GCS_BUCKET")
    dest_path = "pickleball/outputs/video_#{video.id}_analysis_#{analysis.id}.json"
    "gs://#{bucket}/#{dest_path}"
  end
end
