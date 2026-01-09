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
      VideoAnalysisJob.perform_later(@video.id)
      redirect_to @video, notice: "Upload received. We are analyzing your video now."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def native_upload
    @video = @owner.videos.build(video_params)
    @video.uploaded_at = Time.current

    if @video.save
      VideoAnalysisJob.perform_later(@video.id)
      render json: { video_id: @video.id, redirect_url: video_url(@video) }
    else
      render json: { errors: @video.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    @analysis = @video.analyses.order(created_at: :desc).first
    @conversation = @video.conversation
  end

  def status
    @analysis = @video.analyses.order(created_at: :desc).first
    render partial: "status", locals: { video: @video, analysis: @analysis }
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
end
