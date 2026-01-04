class ArtistFollowsController < ApplicationController
  before_action :authenticate_any_user!
  before_action :set_artist_for_create, only: [:create]
  before_action :set_artist_for_destroy, only: [:destroy]

  def create
    ArtistFollow.create!(follower: current_follower, artist: @artist)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @artist }
    end
  end

  def destroy
    follow = ArtistFollow.find(params[:id])
    @artist = follow.artist

    # Add security check to ensure current user owns this follow
    if follow.follower == current_follower
      follow.destroy
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @artist }
    end
  end

  private

  def authenticate_any_user!
    unless user_signed_in? || owner_signed_in? || artist_signed_in? || promoter_signed_in?
      redirect_to new_user_session_path
    end
  end

  def current_follower
    current_user || current_owner || current_artist || current_promoter
  end

  def set_artist_for_create
    @artist = Artist.find(params[:artist_id])
  end

  def set_artist_for_destroy
    follow = ArtistFollow.find(params[:id])
    @artist = follow.artist
  end
end
