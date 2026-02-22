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
    params.fetch(:video, {}).permit(:title, :notes, :source, :original_video)
  end

  def maybe_finalize_analysis(analysis)
    cv = analysis.cv_results || {}
    output_uri = cv["output_uri"]
    return if output_uri.blank?

    storage = Gcp::StorageClient.new(bucket_name: ENV.fetch("GCS_BUCKET"))
    raw = storage.download_text(output_uri)
    payload = ModelRunner::PayloadAdapter.normalize(JSON.parse(raw))

    summary = ModelRunner::PayloadAdapter.summary_for(payload)
    if summary.blank? && payload["feedback_error"].present?
      summary = "Analysis complete, but feedback was unavailable: #{payload["feedback_error"]}"
    end

    analysis.update!(
      status: :complete,
      completed_at: Time.current,
      cv_results: payload,
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
    return if msg.include?("object not found") || msg.include?("Not Found")
    Rails.logger.error("Status poll failed for analysis #{analysis.id}: #{e.class} #{e.message}")
  end
end
