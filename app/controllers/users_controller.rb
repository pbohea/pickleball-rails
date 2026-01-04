class UsersController < ApplicationController
  before_action :authenticate_user!, except: [:landing]
  before_action :set_user, only: [:landing]

  def dashboard
    @user = current_user
    @favorite_artists = @user.followed_artists
    @favorite_venues = @user.followed_venues
  end

  def landing
    @user = User.find(params[:id])
    # Add any authorization check if needed
    redirect_to root_path unless @user == current_user
  end

  private

  def set_user
    @user = User.find(params[:id])
  end
end
