class VideosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_owner
  before_action :set_video, only: [:show, :status]

  def index
    @processing_videos = @owner.videos.where(status: [:uploaded, :processing]).order(created_at: :desc)
    @finished_videos = @owner.videos.where(status: :analyzed).order(created_at: :desc)
    @active_tab = params[:tab].presence_in(%w[processing finished]) || "processing"
  end

  def new
    @video = @owner.videos.build
  end

  def create
    @video = @owner.videos.build(video_params)
    @video.uploaded_at = Time.current

    if @video.save
      Rails.logger.info("Video create success id=#{@video.id} attached=#{@video.original_video.attached?}")
      VideoAnalysisJob.perform_now(@video.id)
      redirect_to @video, notice: "Upload received. We are analyzing your video now."
    else
      Rails.logger.warn("Video create failed errors=#{@video.errors.full_messages.join(", ")}")
      render :new, status: :unprocessable_entity
    end
  end

  def native_upload
    @video = @owner.videos.build(video_params)
    @video.uploaded_at = Time.current

    if @video.save
      Rails.logger.info("Video native upload success id=#{@video.id} attached=#{@video.original_video.attached?}")
      VideoAnalysisJob.perform_now(@video.id)
      render json: { video_id: @video.id, redirect_url: video_url(@video) }
    else
      Rails.logger.warn("Video native upload failed errors=#{@video.errors.full_messages.join(", ")}")
      render json: { errors: @video.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    @analysis = @video.analyses.order(created_at: :desc).first
    @conversation = @video.conversation
  end

  def status
    @analysis = @video.analyses.order(created_at: :desc).first
    maybe_finalize_analysis(@analysis) if @analysis&.running?
    render :status, locals: { video: @video, analysis: @analysis }
  end

  private

  def set_owner
    @owner = current_user
  end

  def set_video
    @video = @owner.videos.find(params[:id])
  end

  def video_params
    params.fetch(:video, {}).permit(:title, :notes, :source, :original_video, :analysis_start, :analysis_end)
  end

  def maybe_finalize_analysis(analysis)
    cv = analysis.cv_results || {}
    output_uri = cv["output_uri"]
    if output_uri.blank?
      maybe_fail_from_runner!(analysis, cv)
      maybe_fail_stale_analysis!(analysis)
      return
    end

    storage = Gcp::StorageClient.new(bucket_name: ENV.fetch("GCS_BUCKET"))
    raw = storage.download_text(output_uri)
    payload = ModelRunner::PayloadAdapter.normalize(JSON.parse(raw))
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

    conversation = @video.conversation || @video.build_conversation(user: @video.user, analysis: analysis)
    conversation.analysis = analysis
    conversation.save!
    conversation.messages.create!(role: :assistant, content: summary, metadata: {}) if summary.present?

    @video.update!(status: :analyzed, processed_at: Time.current)
    PushNotifications::ApnsSender.new.send_analysis_complete(user: @video.user, video: @video)
  rescue StandardError => e
    # If output isn't ready yet, just keep polling.
    msg = e.message.to_s
    if msg.include?("object not found") || msg.include?("Not Found")
      maybe_fail_from_runner!(analysis, cv)
      maybe_fail_stale_analysis!(analysis)
      return
    end
    Rails.logger.error("Status poll failed for analysis #{analysis.id}: #{e.class} #{e.message}")
  end

  def maybe_fail_from_runner!(analysis, cv)
    return unless cv["request_id"].present?
    return if ENV["MODEL_RUNNER_URL"].blank?

    client = ModelRunner::HttpClient.new(
      url: ENV.fetch("MODEL_RUNNER_URL"),
      token: ENV["MODEL_RUNNER_TOKEN"]
    )
    job = client.job_status(cv["request_id"])
    return unless job["status"] == "failed"

    message = runner_failure_message(job)
    analysis.update!(
      status: :failed,
      completed_at: Time.current,
      summary: message,
      cv_results: cv.merge("runner_job" => job)
    )
    @video.update!(status: :failed)
  rescue StandardError => e
    Rails.logger.error("Runner status check failed for analysis #{analysis.id}: #{e.class} #{e.message}")
  end

  def runner_failure_message(job)
    stderr = job["stderr_tail"].to_s
    if stderr.include?("Could not match")
      "We couldn't find you based on that description. Please try a different clothing description."
    else
      "Analysis failed in the model runner. Please try uploading again."
    end
  end

  def maybe_fail_stale_analysis!(analysis)
    timeout_minutes = ENV.fetch("MODEL_RUNNER_STALE_MINUTES", "30").to_i
    return if timeout_minutes <= 0
    return if analysis.started_at.blank?
    return if analysis.started_at > timeout_minutes.minutes.ago

    analysis.update!(status: :failed)
    @video.update!(status: :failed)
    Rails.logger.error("Analysis marked failed due to staleness analysis_id=#{analysis.id} timeout_minutes=#{timeout_minutes}")
  end
end
