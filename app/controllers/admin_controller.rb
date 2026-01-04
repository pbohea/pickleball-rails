class AdminController < ApplicationController
  before_action :authorize_admin!

  def dashboard
    @pending_venue_requests = VenueRequest.pending.order(created_at: :desc)
    @recent_approved = VenueRequest.approved.order(updated_at: :desc).limit(5)
    @recent_rejected = VenueRequest.rejected.order(updated_at: :desc).limit(5)
    
    @stats = {
      total_requests: VenueRequest.count,
      pending_count: VenueRequest.pending.count,
      approved_count: VenueRequest.approved.count,
      rejected_count: VenueRequest.rejected.count,
      ownership_claims: VenueRequest.where(ownership_claim: true).count,
      new_venue_requests: VenueRequest.where(request_type: 'new_venue').count
    }
  end

  def metrics
    @time_range = params[:time_range] || 'all_time'
    @city_filter = params[:city] || 'everywhere'
    
    # Get date range based on filter
    @start_date = case @time_range
                  when 'last_week'
                    1.week.ago
                  when 'last_month'
                    1.month.ago
                  else
                    nil # all time
                  end
    
    # Basic counts (not time-filtered for simplicity)
    @users_count = User.count
    @artists_count = Artist.count
    @owners_count = Owner.count
    @venues_count = Venue.count
    
    # Event counts with time filtering
    @upcoming_events_count = upcoming_events_scope.count
    @total_events_count = all_events_scope.count
    
    # Get unique cities for filter dropdown
    @cities = Venue.where.not(city: nil).distinct.pluck(:city).sort
    
    # Popular venues and artists
    @venues_by_events = top_venues_by_events
    @venues_by_followers = top_venues_by_followers
    @artists_by_events = top_artists_by_events
    @artists_by_followers = top_artists_by_followers
  end

  def venue_requests
    @venue_requests = VenueRequest.order(created_at: :desc)
    
    # Filter by status if provided
    if params[:status].present? && VenueRequest.statuses.key?(params[:status])
      @venue_requests = @venue_requests.where(status: params[:status])
    end

    # Filter by type if provided
    if params[:type].present? && %w[new_venue existing_venue_claim].include?(params[:type])
      @venue_requests = @venue_requests.where(request_type: params[:type])
    end
  end

  private

  def authorize_admin!
    unless is_admin?
      redirect_to root_path, alert: "Access denied."
    end
  end

  def is_admin?
    return false unless user_signed_in?
    admin_emails = ENV.fetch('ADMIN_EMAILS', 'admin@pickleball.co').split(',').map(&:strip)
    admin_emails.include?(current_user.email)
  end

  # Event scopes with time filtering
  def upcoming_events_scope
    scope = Event.upcoming
    scope = scope.where('start_time >= ?', @start_date) if @start_date
    scope
  end
  
  def all_events_scope
    scope = Event.all
    scope = scope.where('start_time >= ?', @start_date) if @start_date
    scope
  end
  
  # Venue scope with city filtering
  def venues_scope
    scope = Venue.all
    scope = scope.where(city: @city_filter) if @city_filter != 'everywhere'
    scope
  end
  
  def top_venues_by_events
    scope = venues_scope
    
    # Join with events and count
    scope.left_joins(:events)
         .select('venues.*, COUNT(events.id) as event_count')
         .group('venues.id')
         .order('event_count DESC')
         .limit(10)
  end
  
  def top_venues_by_followers
    scope = venues_scope
    
    # Join with venue_follows and count
    scope.left_joins(:venue_follows)
         .select('venues.*, COUNT(venue_follows.id) as follower_count')
         .group('venues.id')
         .order('follower_count DESC')
         .limit(10)
  end
  
  def top_artists_by_events
    Artist.left_joins(:events)
          .select('artists.*, COUNT(events.id) as event_count')
          .group('artists.id')
          .order('event_count DESC')
          .limit(10)
  end
  
  def top_artists_by_followers
    Artist.left_joins(:artist_follows)
          .select('artists.*, COUNT(artist_follows.id) as follower_count')
          .group('artists.id')
          .order('follower_count DESC')
          .limit(10)
  end
end
