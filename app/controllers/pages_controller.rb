class PagesController < ApplicationController
  def about
  end

  def artists_about
    @featured_artist = Artist.find_by(slug: "dz-riley") ||
                       Artist.find_by(username: "DZ Riley") ||
                       Artist.order(Arel.sql("RANDOM()")).first
  end

  def owners_about
  end

  def home
        @featured_events = Event
      .recently_posted(24)
      .upcoming
      .includes(:artist, :venue)          # eager load for speed
      .reorder(created_at: :desc)
      .limit(3) 
       # 2) Recently signed-up artists (within last 14 days)
        @new_artists = Artist
      .where("created_at >= ?", 2.weeks.ago)
      .order(created_at: :desc)
      .limit(6)
  end

  def home_search
  end

  def privacy
  end

  def feedback
  end

  def submit_feedback
    # Determine who is submitting
    submitter_email = nil
    submitter_type = nil

    if user_signed_in?
      submitter_email = current_user.email
      submitter_type = "User"
    elsif artist_signed_in?
      submitter_email = current_artist.email
      submitter_type = "Artist"
    elsif owner_signed_in?
      submitter_email = current_owner.email
      submitter_type = "Owner"
    end

    # Send the feedback email
    FeedbackMailer.feedback_submission(
      feedback_params,
      submitter_email,
      submitter_type
    ).deliver_now

    redirect_to thank_you_path
  end

  def thank_you
  end


  

  def menu
    # Force no caching for the menu page - this is crucial for iOS
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, private"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers["Last-Modified"] = Time.current.httpdate
    response.headers["Vary"] = "Accept-Encoding"

    # Optional: Add ETag based on authentication state to force refresh
    auth_state = "#{user_signed_in?}-#{artist_signed_in?}-#{owner_signed_in?}-#{promoter_signed_in?}"
    response.headers["ETag"] = Digest::MD5.hexdigest("menu-#{auth_state}-#{Time.current.to_i}")

    # Log the current authentication state for debugging
    Rails.logger.info "Menu page - User: #{user_signed_in?}, Artist: #{artist_signed_in?}, Owner: #{owner_signed_in?}"
  end


  private 

  def find_nearby_events_for_home(lat, lng)
    # Use the same logic as EventsController but simplified for home page
    radius = 5.0 # Fixed 5 miles as specified
    
    # Validate coordinates
    return [] if lat < -90 || lat > 90 || lng < -180 || lng > 180
    
    begin
      # Find nearby venues
      nearby_venues = Venue.near([lat, lng], radius, units: :mi, order: false)
      venue_ids = nearby_venues.pluck(:id)
      
      return [] if venue_ids.empty?
      
      # Get upcoming events at those venues
      events = Event.upcoming
                   .includes(:venue, :artist)
                   .where(venue_id: venue_ids)
                   .limit(10) # Limit to 10 events for home page
      
      # Sort by start time (soonest first)
      events.order(:start_time)
      
    rescue => e
      Rails.logger.warn "Location search failed on home page: #{e.message}"
      []
    end
  end

  def feedback_params
    params.require(:feedback).permit(:message, categories: [])
  end

end
