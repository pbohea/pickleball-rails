class VideoAnalysisJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)
    analysis = nil
    video.update!(status: :processing)

    desc = video.notes.to_s.strip
    if desc.blank?
      video.update!(status: :failed)
      raise "Missing target description (notes)"
    end

    analysis = video.analyses.create!(
      status: :running,
      started_at: Time.current,
      model_version: "ready-score-v1",
      cv_results: {}
    )

    Rails.logger.info("VideoAnalysisJob start video_id=#{video.id} analysis_id=#{analysis.id} attached=#{video.original_video.attached?}")

    unless video.original_video.attached?
      attempts = analysis.cv_results["enqueue_attempts"].to_i + 1
      analysis.update!(cv_results: analysis.cv_results.merge("enqueue_attempts" => attempts))
      if attempts <= 10
        VideoAnalysisJob.set(wait: 30.seconds).perform_later(video.id)
        return
      end
      analysis.update!(status: :failed)
      video.update!(status: :failed)
      return
    end

    analysis.analysis_events.create!(
      event_type: "analysis_started",
      payload: { message: "Analysis request dispatched" },
      timestamp_ms: (Time.current.to_f * 1000).to_i
    )

    input_uri = ensure_gcs_input(video)
    output_uri = build_output_uri(video, analysis)
    clip_start = ENV.fetch("MODEL_RUNNER_START", "00:00:00")
    base_cv_results = {
      "output_uri" => output_uri,
      "input_uri" => input_uri,
      "desc" => desc,
      "start" => clip_start,
      "poll_attempts" => 0
    }
    # Persist output location before dispatch so status polling can recover even if process exits mid-request.
    analysis.update!(cv_results: (analysis.cv_results || {}).merge(base_cv_results))

    if ENV["MODEL_RUNNER_URL"].present?
      client = ModelRunner::HttpClient.new(
        url: ENV.fetch("MODEL_RUNNER_URL"),
        token: ENV["MODEL_RUNNER_TOKEN"]
      )

      response = client.enqueue_analysis(
        video_uri: input_uri,
        desc: desc,
        start: clip_start,
        output_uri: output_uri,
        duration: ENV["MODEL_RUNNER_DURATION"],
        fps: ENV["MODEL_RUNNER_FPS"],
        width: ENV["MODEL_RUNNER_WIDTH"],
        select_t_sec: ENV["MODEL_RUNNER_SELECT_T_SEC"],
        baseline: ENV["MODEL_RUNNER_BASELINE"],
        ball_model: ENV["MODEL_RUNNER_BALL_MODEL"],
        pose_model: ENV["MODEL_RUNNER_POSE_MODEL"]
      )

      analysis.update!(
        cv_results: base_cv_results.merge(
          "runner" => "http",
          "request_id" => response[:request_id],
          "runner_response" => response[:raw]
        )
      )
    else
      client = Gcp::CloudRunJobsClient.new(
        project: ENV.fetch("GCP_PROJECT"),
        region: ENV.fetch("GCP_REGION", "us-central1")
      )

      args = [
        "--video=#{input_uri}",
        "--desc=#{desc}",
        "--start=#{clip_start}",
        "--output=#{output_uri}"
      ]

      execution_name = client.run_job(ENV.fetch("PICKLEBALL_JOB_NAME"), args: args)

      analysis.update!(
        cv_results: base_cv_results.merge(
          "runner" => "cloud_run_job",
          "execution_name" => execution_name
        )
      )
    end

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
