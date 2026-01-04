class ArtistsController < ApplicationController
  before_action :set_artist, only: [:show, :promo_flyer, :promo_flyer_print, :landing, :events]
  before_action :authenticate_artist!, only: [:dashboard, :venue_requests]

  # app/controllers/artists_controller.rb
    def search
    raw = params[:query].to_s.strip

    # normalize curly quotes/backticks to straight apostrophe for the pattern
    normalized = raw.tr("’‘`´‵‶′", "'").downcase
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(normalized)}%"

    # These are the from/to strings for translate()
    from = "’‘`´‵‶′"     # 7 chars to replace
    to   = "'".ljust(from.length, "'")  # 7 apostrophes

    artists = Artist
                .where("LOWER(translate(username, ?, ?)) LIKE ?", from, to, pattern)
                .limit(5)

    artists_json = artists.map do |artist|
      {
        id: artist.id,
        slug: artist.slug,
        username: artist.username,
        bio: artist.bio || "",
        performance_type: artist.performance_type,
        image: artist.image.attached? ? url_for(artist.image) : nil,
      }
    end

    render json: artists_json
  end

  
  def show
    @upcoming_events = @artist.upcoming_events_including_guest
    @past_events     = @artist.past_events_including_guest.limit(10)
  end

  def events
    @upcoming_events = @artist.upcoming_events_including_guest
    @past_events     = @artist.past_events_including_guest.limit(10)
  end

  def dashboard
    @artist          = current_artist
    @upcoming_events = @artist.upcoming_events_including_guest
    @past_events     = @artist.past_events_including_guest
    @favorite_artists = @artist.followed_artists
    @favorite_venues  = @artist.followed_venues
  end

  def promo_flyer
    require "rqrcode"

    @qr_code = RQRCode::QRCode.new("https://apps.apple.com/us/app/your-app-placeholder/id6753730148")
  rescue ActiveRecord::RecordNotFound
    @artist = nil
    @qr_code = nil
  rescue StandardError => e
    Rails.logger.error "QR Code generation error: #{e.message}"
    @qr_code = nil
    render layout: "print"
  end

  def promo_flyer_print
    require "rqrcode"

    @qr_code = RQRCode::QRCode.new("https://apps.apple.com/us/app/your-app-placeholder/id6753730148")
    render layout: "print"
  rescue ActiveRecord::RecordNotFound
    @artist = nil
    @qr_code = nil
  rescue StandardError => e
    Rails.logger.error "QR Code generation error: #{e.message}"
    @qr_code = nil
  end

  def venue_requests
    @artist = current_artist
    @venue_requests = VenueRequest.where(requester_type: "artist", requester_id: @artist.id)
                                  .order(created_at: :desc)
  end

  def landing
    #@artist = Artist.find(params[:id])
    # Add any authorization check if needed
    redirect_to root_path unless @artist == current_artist
  end

  private

  def set_artist
    @artist = Artist.find_by!(slug: params[:id])
  end
end
