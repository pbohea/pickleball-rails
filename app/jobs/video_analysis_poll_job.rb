class VideoAnalysisPollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 25
  RETRY_DELAY = 30.seconds

  def perform(analysis_id)
    analysis = Analysis.find(analysis_id)
    return if analysis.complete? || analysis.failed?

    video = analysis.video
    cv = analysis.cv_results || {}

    execution_name = cv["execution_name"]
    request_id = cv["request_id"]
    output_uri = cv["output_uri"]
    attempts = cv["poll_attempts"].to_i

    if output_uri.blank?
      analysis.update!(status: :failed)
      video.update!(status: :failed)
      return
    end

    payload = fetch_output_payload(output_uri)
    if payload
      finalize_analysis!(analysis, video, payload, cv)
      return
    end

    if request_id.present? && ENV["MODEL_RUNNER_URL"].present?
      client = ModelRunner::HttpClient.new(
        url: ENV.fetch("MODEL_RUNNER_URL"),
        token: ENV["MODEL_RUNNER_TOKEN"]
      )
      runner_job = client.job_status(request_id)
      if runner_job["status"] == "failed"
        message = runner_failure_message(runner_job)
        analysis.update!(
          status: :failed,
          completed_at: Time.current,
          summary: message,
          cv_results: cv.merge("runner_job" => runner_job)
        )
        video.update!(status: :failed)
        return
      end
    end

    if execution_name.present?
      client = Gcp::CloudRunJobsClient.new(
        project: ENV.fetch("GCP_PROJECT"),
        region: ENV.fetch("GCP_REGION", "us-central1")
      )

      status = client.execution_status(execution_name)
      if status == :failed
        analysis.update!(status: :failed)
        video.update!(status: :failed)
        return
      end
    end

    attempts += 1
    if attempts >= MAX_ATTEMPTS
      analysis.update!(status: :failed, cv_results: cv.merge("poll_attempts" => attempts))
      video.update!(status: :failed)
    else
      analysis.update!(cv_results: cv.merge("poll_attempts" => attempts))
      VideoAnalysisPollJob.set(wait: RETRY_DELAY).perform_later(analysis.id)
    end
  rescue StandardError => e
    analysis&.update(status: :failed)
    video&.update(status: :failed)
    Rails.logger.error("VideoAnalysisPollJob failed for analysis #{analysis_id}: #{e.class} #{e.message}")
    raise
  end

  private

  def fetch_output_payload(output_uri)
    storage = Gcp::StorageClient.new(bucket_name: ENV.fetch("GCS_BUCKET"))
    raw = storage.download_text(output_uri)
    JSON.parse(raw)
  rescue StandardError => e
    msg = e.message.to_s
    return nil if msg.include?("object not found") || msg.include?("Not Found")
    raise
  end

  def finalize_analysis!(analysis, video, payload, cv)
    payload = ModelRunner::PayloadAdapter.normalize(payload)
    merged_payload = cv.merge(payload)
    summary = ModelRunner::PayloadAdapter.summary_for(merged_payload)
    if summary.blank? && merged_payload["feedback_error"].present?
      summary = "Analysis complete, but feedback was unavailable: #{merged_payload["feedback_error"]}"
    end

    analysis.update!(
      status: :complete,
      completed_at: Time.current,
      cv_results: merged_payload,
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
  end

  def runner_failure_message(runner_job)
    stderr = runner_job["stderr_tail"].to_s
    if stderr.include?("Could not match")
      "We couldn't find you based on that description. Please try a different clothing description."
    else
      "Analysis failed in the model runner. Please try uploading again."
    end
  end
end
