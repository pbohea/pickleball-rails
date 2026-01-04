class NotificationTokensController < ApplicationController
  before_action :authenticate_any_user_type!
  skip_before_action :verify_authenticity_token

  def create
    Rails.logger.info "🔐 current_user: #{current_user&.id || "nil"}"
    Rails.logger.info "🔐 current_artist: #{current_artist&.id || "nil"}"
    Rails.logger.info "🔐 current_owner: #{current_owner&.id || "nil"}"
    
    current_user_entity.notification_tokens.find_or_create_by!(notification_token_params)
    head :created
  end

  private

  def notification_token_params
    params.require(:notification_token).permit(:token, :platform)
  end

  def authenticate_any_user_type!
    unless user_signed_in? || artist_signed_in? || owner_signed_in?
      head :unauthorized
    end
  end

  def current_user_entity
    return current_user if user_signed_in?
    return current_artist if artist_signed_in?
    return current_owner if owner_signed_in?
    nil
  end
end
