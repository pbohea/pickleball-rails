class VenueFollowsController < ApplicationController
  before_action :authenticate_any_user!
  before_action :set_venue_for_create, only: [:create]
  before_action :set_venue_for_destroy, only: [:destroy]

  def create
    current_follower.venue_follows.create!(venue: @venue)

    respond_to do |format|
      format.turbo_stream  # renders create.turbo_stream.erb
      format.html { redirect_to @venue }
    end
  end

  def destroy
    current_follower.venue_follows.find_by(venue: @venue)&.destroy

    respond_to do |format|
      format.turbo_stream  # renders destroy.turbo_stream.erb
      format.html { redirect_to @venue }
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

  def set_venue_for_create
    @venue = Venue.find(params[:venue_id])
  end

  def set_venue_for_destroy
    follow = VenueFollow.find(params[:id])
    @venue = follow.venue
  end
end
