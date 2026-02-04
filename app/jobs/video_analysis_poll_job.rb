class VideoAnalysisPollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 25
  RETRY_DELAY = 30.seconds

  def perform(analysis_id)
    analysis = Analysis.find(analysis_id)
    video = analysis.video
    cv = analysis.cv_results || {}

    execution_name = cv["execution_name"]
    output_uri = cv["output_uri"]
    attempts = cv["poll_attempts"].to_i

    if execution_name.blank? || output_uri.blank?
      analysis.update!(status: :failed)
      video.update!(status: :failed)
      return
    end

    client = Gcp::CloudRunJobsClient.new(
      project: ENV.fetch("GCP_PROJECT"),
      region: ENV.fetch("GCP_REGION", "us-central1")
    )

    status = client.execution_status(execution_name)

    case status
    when :succeeded
      storage = Gcp::StorageClient.new(bucket_name: ENV.fetch("GCS_BUCKET"))
      raw = storage.download_text(output_uri)
      payload = JSON.parse(raw)

      summary = payload["feedback"]
      if summary.blank? && payload["feedback_error"].present?
        summary = "Analysis complete, but feedback was unavailable: #{payload["feedback_error"]}"
      end

      analysis.update!(
        status: :complete,
        completed_at: Time.current,
        cv_results: payload,
        summary: summary
      )

      conversation = video.conversation || video.build_conversation(user: video.user, analysis: analysis)
      conversation.analysis = analysis
      conversation.save!
      if summary.present?
        conversation.messages.create!(role: :assistant, content: summary, metadata: {})
      end

      video.update!(status: :analyzed, processed_at: Time.current)
      PushNotifications::ApnsSender.new.send_analysis_complete(user: video.user, video: video)
    when :failed
      analysis.update!(status: :failed)
      video.update!(status: :failed)
    else
      attempts += 1
      if attempts >= MAX_ATTEMPTS
        analysis.update!(status: :failed, cv_results: cv.merge("poll_attempts" => attempts))
        video.update!(status: :failed)
      else
        analysis.update!(cv_results: cv.merge("poll_attempts" => attempts))
        VideoAnalysisPollJob.set(wait: RETRY_DELAY).perform_later(analysis.id)
      end
    end
  rescue StandardError => e
    analysis&.update(status: :failed)
    video&.update(status: :failed)
    Rails.logger.error("VideoAnalysisPollJob failed for analysis #{analysis_id}: #{e.class} #{e.message}")
    raise
  end
end
