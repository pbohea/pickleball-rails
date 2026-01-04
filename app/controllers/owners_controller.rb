class OwnersController < ApplicationController
  before_action :authenticate_owner!, except: [:landing]
  before_action :set_owner, only: [:landing]

  def dashboard
    @owner = current_owner
    @venues = @owner.venues
    @favorite_artists = @owner.followed_artists
    @favorite_venues = @owner.followed_venues
    @upcoming_events = @owner.upcoming_events.includes(:venue, :artist)
    @past_events = @owner.past_events.includes(:venue, :artist)
  end

  def venue_requests
    @owner = current_owner
    @venue_requests = VenueRequest.where(requester_type: "owner", requester_id: @owner.id)
                                  .order(created_at: :desc)
  end

  def landing
    @owner = Owner.find(params[:id])
    # Add any authorization check if needed
    redirect_to root_path unless @owner == current_owner
  end

  private

  def set_owner
    @owner = Owner.find(params[:id])
  end
end
