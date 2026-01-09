class NotificationTokensController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_user!

  def create
    token = params[:token].to_s.strip
    platform = params[:platform].to_s.strip.presence || "iOS"

    if token.blank?
      render json: { error: "token is required" }, status: :unprocessable_entity
      return
    end

    notification_token = current_user.notification_tokens.find_or_initialize_by(token: token)
    notification_token.platform = platform

    if notification_token.save
      render json: { status: "ok" }
    else
      render json: { errors: notification_token.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
