class VideoAnalysisJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)
    analysis = nil
    video.update!(status: :processing)

    analysis = video.analyses.create!(
      status: :running,
      started_at: Time.current,
      model_version: "placeholder-v0",
      cv_results: {}
    )

    analysis.analysis_events.create!(
      event_type: "analysis_started",
      payload: { message: "Placeholder analysis started" },
      timestamp_ms: (Time.current.to_f * 1000).to_i
    )

    summary = "Placeholder feedback: work on early prep, stable footwork, and follow-through. We'll replace this with CV + LLM output."

    analysis.update!(
      status: :complete,
      completed_at: Time.current,
      cv_results: {
        placeholder: true,
        notes: "Replace with CV model output"
      },
      summary: summary
    )

    conversation = video.conversation || video.build_conversation(user: video.user, analysis: analysis)
    conversation.analysis = analysis
    conversation.save!
    conversation.messages.create!(role: :assistant, content: summary, metadata: {})

    video.update!(status: :analyzed, processed_at: Time.current)
  rescue StandardError => e
    video&.update(status: :failed)
    analysis&.update(status: :failed)
    Rails.logger.error("VideoAnalysisJob failed for video #{video_id}: #{e.class} #{e.message}")
    raise
  end
end
