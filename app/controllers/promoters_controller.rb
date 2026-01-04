# app/controllers/promoters_controller.rb
class PromotersController < ApplicationController
  before_action :authenticate_promoter!

  def dashboard
    @promoter = current_promoter
    @artists  = @promoter.followed_artists
    @venues   = @promoter.followed_venues
    @upcoming_events = Event.upcoming
                            .where(promoter_id: @promoter.id)
                            .includes(:venue, :artist)
  end

  def artists
    @promoter = current_promoter
    @artists  = @promoter.followed_artists
  end

  def venues
    @promoter = current_promoter
    @venues   = @promoter.followed_venues
  end
end
