class VideosController < ApplicationController
  before_action :set_owner
  before_action :set_video, only: [:show, :status]

  def index
    @videos = @owner.videos.order(created_at: :desc)
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
    @owner = user_signed_in? ? current_user : guest_user
  end

  def set_video
    @video = @owner.videos.find(params[:id])
  end

  def video_params
    params.fetch(:video, {}).permit(:title, :notes, :source, :original_video)
  end

  def guest_user
    if session[:guest_user_id].present?
      user = User.find_by(id: session[:guest_user_id])
      return user if user
    end

    user = User.create!(
      email: "guest-#{SecureRandom.uuid}@example.com",
      password: SecureRandom.hex(16)
    )
    session[:guest_user_id] = user.id
    user
  end
end
