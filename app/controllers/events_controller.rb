class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy]
  before_action :authorize_owner_or_admin!, only: %i[edit update destroy]

  def landing
    #just renders landing page with form
  end

  # GET /events
  def index
    Rails.logger.info "🔍 EVENTS INDEX HIT - User-Agent: #{request.user_agent}"
    Rails.logger.info "🔍 REQUEST PARAMS: #{params.inspect}"

    # Require location parameters for search
    if params[:address].blank? && params[:lat].blank?
      Rails.logger.info "❌ No location parameters provided, redirecting to landing"
      redirect_to events_landing_path, alert: "Please enter a location to search for events."
      return
    end

    # Your existing index logic...
    if params[:address].present? || params[:lat].present?
      @events = find_nearby_events
      @search_params = extract_search_params
    else
      @events = []
      @search_params = nil
    end

    # Handle error cases - don't apply date filter if there's an error
    if @error_message || @no_results_message
      @events = []
    else
      @events = apply_date_range_filter(@events)
    end

    respond_to do |format|
      format.html
      format.json { render json: @events }
      format.turbo_stream { render :index }
    end
  end

  # GET /events/nearby - New filtered endpoint
  def nearby
    Rails.logger.info "🔍 NEARBY ENDPOINT HIT with params: #{params.inspect}"

    @events = find_nearby_events
    @search_params = extract_search_params

    # Apply date range filter
    @events = apply_date_range_filter(@events)

    Rails.logger.info "📊 Found #{@events.count} events after filtering"
    Rails.logger.info "🎯 Search params: #{@search_params}"

    respond_to do |format|
      format.html { render :index }
      format.json { render :nearby }
    end
  end

  # GET /events/1
  def show
    @event = Event.find(params[:id])
  end

  # GET /events/new
  def new
    @event = Event.new
  end

  # GET /events/1/edit
  def edit
  end

  # POST /events
  def create
    # Check for venue verification if an artist is creating the event
    if artist_signed_in? && params[:venue_verification] != "1"
      @event = Event.new(event_params)
      flash.now[:alert] = "Please verify that the venue information is correct before creating the event."
      render :new, status: :unprocessable_entity
      return
    end

    # Check for artist verification ONLY if an owner is creating the event AND an artist_id is provided
    if owner_signed_in? && params[:event][:artist_id].present? && params[:artist_verification] != "1"
      @event = Event.new(event_params)
      flash.now[:alert] = "Please verify that the artist information is correct before creating the event."
      render :new, status: :unprocessable_entity
      return
    end

    if promoter_signed_in? && params[:event][:artist_id].present? && params[:artist_verification] != "1"
      @event = Event.new(event_params)
      flash.now[:alert] = "Please verify that the artist information is correct before creating the event."
      render :new, status: :unprocessable_entity
      return
    end

    @event = Event.new(event_params)

    if owner_signed_in?
      # Owners must choose from their venues
      @event.venue = current_owner.venues.find_by(id: params.dig(:event, :venue_id)) || @event.venue
    elsif promoter_signed_in?
      # Promoters: leave venue as already set by event_params (supports venue_slug)
      @event.promoter = current_promoter
    end

    respond_to do |format|
      if @event.save
        sync_event_artists(@event)
        send_event_notifications(@event)
        # Redirect based on who created the event
        if artist_signed_in?
          format.html { redirect_to @event, notice: "Event was successfully created." }
        elsif owner_signed_in?
          format.html { redirect_to @event, notice: "Event was successfully created." }
        else
          format.html { redirect_to @event, notice: "Event was successfully created." }
        end
        format.json { render :show, status: :created, location: @event }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @event.errors, status: :unprocessable_entity }
      end
    end

    # Send notifications after successful save
  end

    # PATCH/PUT /events/1
  def update
    cleaned = event_params.to_h.symbolize_keys

    # Make venue immutable on edit
    cleaned.except!(:venue_id, :venue_slug)

    # Normalize primary artist: prefer DB artist if present; else manual name.
    if cleaned[:artist_id].present?
      cleaned[:artist_name] = nil
    elsif cleaned[:artist_name].present?
      cleaned[:artist_id] = nil
    else
      # If both are blank, leave existing values and let model validation handle emptiness if any.
      cleaned.except!(:artist_id, :artist_name)
    end

    respond_to do |format|
      if @event.update(cleaned)
        sync_event_artists(@event)
        format.html { redirect_to @event, notice: "Event was successfully updated." }
        format.json { render :show, status: :ok, location: @event }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @event.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /events/1
  def destroy
    @event.destroy!

    respond_to do |format|
      format.html {
        if artist_signed_in?
          redirect_to artist_dashboard_path, status: :see_other, notice: "Event has been cancelled successfully."
        elsif owner_signed_in?
          redirect_to owner_dashboard_path, status: :see_other, notice: "Event has been cancelled successfully."
        elsif promoter_signed_in?
          redirect_to promoter_dashboard_path, status: :see_other, notice: "Event has been cancelled successfully."
        else
          redirect_to admin_dashboard_path, status: :see_other, notice: "Event has been cancelled successfully."
        end
      }
    end
  end

  def map
    # Geocode if lat/lng missing but address is provided
    if params[:lat].blank? || params[:lng].blank?
      if params[:address].present?
        coords = geocode_address(params[:address])
        if coords
          params[:lat] = coords[0]
          params[:lng] = coords[1]
        else
          flash[:alert] = "Could not locate address"
          redirect_to map_path and return
        end
      end
    end

    @center_lat = params[:lat]&.to_f
    @center_lng = params[:lng]&.to_f
    @selected_venue_id = params[:venue_id]&.to_i

    if @center_lat && @center_lng
      radius = search_radius
      @events = Event.upcoming
                     .includes(:venue, :artist)
                     .where(venue_id: Venue.near([@center_lat, @center_lng], radius, units: :mi, order: false).pluck(:id))

      # Apply date range filter
      @events = apply_date_range_filter(@events)
    else
      @events = []
    end

    respond_to do |format|
      format.json # renders map.json.jbuilder
      format.html
    end
  end

  def map_landing
    if params[:lat].present? && params[:lng].present?
      redirect_to events_map_path(
        lat: params[:lat],
        lng: params[:lng],
        address: params[:address],
        radius: params[:radius],
        date_range: params[:date_range],
      )
    end
  end

  def date_options_ajax
    venue = if params[:venue_slug].present?
        Venue.find_by!(slug: params[:venue_slug])
      elsif params[:venue_id].present?
        Venue.find(params[:venue_id])
      end

    date_options = helpers.date_options(venue)

    respond_to do |format|
      format.json { render json: { date_options: date_options } }
    end
  end

  def time_options_ajax
    venue = if params[:venue_slug].present?
        Venue.find_by!(slug: params[:venue_slug])
      elsif params[:venue_id].present?
        Venue.find(params[:venue_id])
      end
    selected_date = params[:date]

    start_times = helpers.time_options(venue, selected_date)

    respond_to do |format|
      format.json {
        render json: {
                 start_times: start_times,
                 venue_timezone: venue.tz_name,  # Add this line
               }
      }
    end
  end

  def end_time_options_ajax
    venue = if params[:venue_slug].present?
        Venue.find_by!(slug: params[:venue_slug])
      elsif params[:venue_id].present?
        Venue.find(params[:venue_id])
      end
    selected_date = params[:date]
    start_time = params[:start_time]

    end_times = helpers.end_time_options(venue, selected_date, start_time)

    respond_to do |format|
      format.json { render json: { end_times: end_times } }
    end
  end

  def conflicts_ajax
    venue_slug = params[:venue_slug].presence
    venue_id   = params[:venue_id].presence
    date_str   = params[:date].to_s.strip
    start_str  = params[:start_time].to_s.strip
    end_str    = params[:end_time].to_s.strip
    exclude_id = params[:exclude_id].presence

    venue = if venue_slug
      Venue.find_by!(slug: venue_slug)
    elsif venue_id
      Venue.find(venue_id)
    end

    # Must have venue, date, start, AND end to evaluate conflicts on forms
    unless venue && date_str.present? && start_str.present? && end_str.present?
      render json: { ok: true, conflicts: [] } and return
    end

    zone = ActiveSupport::TimeZone[venue.tz_name || 'America/Chicago']

    begin
      d = Date.parse(date_str)
    rescue
      render json: { ok: false, error: "Bad date" }, status: :unprocessable_entity and return
    end

    sh, sm = parse_time_pair(start_str)
    eh, em = parse_time_pair(end_str)

    start_local = zone.local(d.year, d.month, d.day, sh, sm)
    end_local   = zone.local(d.year, d.month, d.day, eh, em)
    end_local  += 1.day if end_local <= start_local # overnight still supported

    new_start_utc = start_local.utc
    new_end_utc   = end_local.utc

    conflicts = Event
      .where(venue_id: venue.id)
      .where.not(id: exclude_id)
      # Strict overlap: allow adjacency
      .where("NOT (end_time <= ? OR start_time >= ?)", new_start_utc, new_end_utc)
      .order(:start_time)

    payload = conflicts.map do |ev|
      {
        id: ev.id,
        artist_name: ev.artist_name || ev.artist&.username || "Event",
        start_time: ev.starts_at_local.strftime("%a %b %-d, %l:%M %p"),
        end_time:   ev.ends_at_local.strftime("%l:%M %p"),
        venue: venue.name,
        url: Rails.application.routes.url_helpers.event_path(ev)
      }
    end

    render json: { ok: true, conflicts: payload }
  end

  private

  def parse_time_pair(val)
    case val
    when String
      parts = val.split(":").map(&:to_i)
      [parts[0] || 0, parts[1] || 0]
    else
      [val.hour, val.min]
    end
  end

  def send_event_notifications(event)
    # 1) Venue followers — always
    if (v_followers = event.venue&.followers).present?
      NewVenueEventNotifier.with(event: event).deliver_later(v_followers)
    end

    # 2) All DB artists attached (primary + additional)
    all_db_artists = event.all_artists
    if all_db_artists.exists?
      all_db_artists.find_each do |a|
        if (followers = a.followers).present?
          NewEventNotifier.with(event: event).deliver_later(followers)
        end
      end
    end

    # 3) Cross-notifies based on who created (unchanged, but ensure primary artist still works)
    if artist_signed_in? && event.venue&.owner_id.present?
      if (owner = Owner.find_by(id: event.venue.owner_id))
        EventAtVenueNotifier.with(event: event).deliver_later(owner)
      end
    end

    if owner_signed_in? && event.artist.present?
      OwnerAddedEventNotifier.with(event: event).deliver_later(event.artist)
    end
  end

  def apply_date_range_filter(events)
    tz_sql = "COALESCE(venues.time_zone, 'America/Chicago')" # fallback for any nil TZs

    case params[:date_range]
    when "today"
      if events.is_a?(ActiveRecord::Relation)
        # Treat stored times as UTC, then convert to venue local time; compare date-to-date
        return events.joins(:venue).where(<<~SQL)
          DATE(((start_time AT TIME ZONE 'UTC') AT TIME ZONE #{tz_sql}))
          = DATE(NOW() AT TIME ZONE #{tz_sql})
        SQL
      else
        return events.select { |e|
          tz = ActiveSupport::TimeZone[e.venue&.time_zone.presence || 'America/Chicago']
          e.start_time.in_time_zone(tz).to_date == tz.today
        }
      end

    when "next_7_days"
      if events.is_a?(ActiveRecord::Relation)
        return events.joins(:venue).where(<<~SQL)
          DATE(((start_time AT TIME ZONE 'UTC') AT TIME ZONE #{tz_sql}))
          BETWEEN DATE(NOW() AT TIME ZONE #{tz_sql})
              AND DATE((NOW() AT TIME ZONE #{tz_sql}) + INTERVAL '7 days')
        SQL
      else
        return events.select { |e|
          tz = ActiveSupport::TimeZone[e.venue&.time_zone.presence || 'America/Chicago']
          d  = e.start_time.in_time_zone(tz).to_date
          (tz.today..(tz.today + 7)).cover?(d)
        }
      end

    else
      events
    end
  end

  def find_nearby_events
    Rails.logger.info "🔍 Starting find_nearby_events"

    # Start with upcoming events
    events = Event.upcoming.includes(:venue, :artist)
    Rails.logger.info "📅 Found #{events.count} upcoming events total"

    # Check if we have valid location coordinates
    coordinates = search_coordinates
    if coordinates.present?
      lat, lng = coordinates

      # Validate coordinates are reasonable
      if lat.nil? || lng.nil? || lat < -90 || lat > 90 || lng < -180 || lng > 180
        Rails.logger.error "❌ Invalid coordinates: [#{lat}, #{lng}]"
        @error_message = "Invalid location coordinates. Please try a different address."
        return []
      end

      radius = search_radius
      Rails.logger.info "📍 Searching near [#{lat}, #{lng}] within #{radius} miles"

      # Use geocoder's near method without ordering to avoid distance column issue
      begin
        nearby_venues = Venue.near([lat, lng], radius, units: :mi, order: false)
        venue_ids = nearby_venues.pluck(:id)
        Rails.logger.info "🏢 Found #{venue_ids.count} venues within radius: #{venue_ids}"

        # If no venues found, return empty array
        if venue_ids.empty?
          Rails.logger.info "❌ No venues found within #{radius} miles"
          @no_results_message = "No venues found within #{radius} miles of your location. Try increasing the search radius."
          return []
        end
      rescue => e
        Rails.logger.warn "⚠️ Geocoder near method failed: #{e.message}, falling back to manual calculation"
        # Fallback: manually filter venues by distance
        all_venues = Venue.where.not(latitude: nil, longitude: nil)
        venue_ids = all_venues.select do |venue|
          distance = Geocoder::Calculations.distance_between(
            [lat, lng],
            [venue.latitude, venue.longitude],
            units: :mi,
          )
          distance <= radius
        end.map(&:id)
        Rails.logger.info "🏢 Manual calculation found #{venue_ids.count} venues within radius"

        # Same check for manual calculation
        if venue_ids.empty?
          Rails.logger.info "❌ No venues found within #{radius} miles (manual calculation)"
          @no_results_message = "No venues found within #{radius} miles of your location. Try increasing the search radius."
          return []
        end
      end

      events = events.where(venue_id: venue_ids)
      Rails.logger.info "🎭 Filtered to #{events.count} events"

      # Apply sorting based on user preference
      sort_by = params[:sort_by] || "date"
      Rails.logger.info "🔀 Sorting by: #{sort_by}"

      if sort_by == "distance"
        # Sort by distance from search location
        events = events.to_a.sort_by do |event|
          if event.venue.latitude && event.venue.longitude
            distance = Geocoder::Calculations.distance_between(
              [lat, lng],
              [event.venue.latitude, event.venue.longitude],
              units: :mi,
            )
            Rails.logger.debug "📏 Event #{event.id} distance: #{distance.round(2)} miles"
            distance
          else
            Rails.logger.warn "⚠️ Event #{event.id} has no venue coordinates"
            Float::INFINITY # Put events without coordinates at the end
          end
        end
      else
        # Sort by date/time (default)
        events = events.to_a.sort_by(&:start_time)
        Rails.logger.info "📅 Sorted by date and time"
      end
    else
      Rails.logger.info "❌ No search coordinates provided or geocoding failed"
      @error_message = "Please provide a valid location to search for events"
      return []
    end

    events
  end

  def search_coordinates
    @search_coordinates ||= begin
        if params[:lat].present? && params[:lng].present? &&
           params[:lat] != "" && params[:lng] != ""
          # Use coordinates if they're provided (from iOS geolocation)
          lat, lng = params[:lat].to_f, params[:lng].to_f

          # Validate coordinates are reasonable
          if lat.between?(-90, 90) && lng.between?(-180, 180)
            [lat, lng]
          else
            Rails.logger.error "❌ Invalid coordinates from params: [#{lat}, #{lng}]"
            nil
          end
        elsif params[:address].present?
          # Fallback to geocoding the address
          address = params[:address].strip

          # Basic validation
          if address.length < 3
            Rails.logger.error "❌ Address too short: '#{address}'"
            nil
          else
            geocode_address(address)
          end
        else
          nil
        end
      end
  end

  def search_radius
    radius = params[:radius]&.to_f || 5.0
    # Clamp between 1 and 60 miles
    [[radius, 1.0].max, 60.0].min
  end

  def geocode_address(address)
    # Add country context to improve geocoding accuracy
    search_query = if address.match?(/^\d{5}(-\d{4})?$/)
        # If it looks like a US ZIP code, add country context
        "#{address}, USA"
      else
        address
      end

    result = Geocoder.search(search_query).first
    if result&.coordinates
      coordinates = result.coordinates
      Rails.logger.info "📍 Geocoded '#{address}' (searched: '#{search_query}') to: #{coordinates[0]}, #{coordinates[1]}"

      # Sanity check - reject coordinates that are clearly wrong for US addresses
      lat, lng = coordinates
      if address.match?(/^\d{5}(-\d{4})?$/) # US ZIP code
        # US is roughly between 24-49 latitude, -125 to -66 longitude
        if lat < 24 || lat > 49 || lng < -125 || lng > -66
          Rails.logger.warn "⚠️ Geocoded coordinates #{lat}, #{lng} seem outside US bounds for ZIP #{address}"
          return nil
        end
      end

      coordinates
    else
      Rails.logger.warn "❌ Failed to geocode address: '#{address}'"
      nil
    end
  end

  def extract_search_params
    coords = search_coordinates
    {
      address: params[:address],
      lat: coords&.first,
      lng: coords&.last,
      radius: search_radius,
      date_range: params[:date_range],
      has_location: coords.present?,
    }
  end

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    ep = params.require(:event).permit(
      :category, :cover, :cover_amount, :date, :description,
      :start_time, :end_time, :indoors,
      :venue_id, :artist_id, :artist_name, :venue_slug,
      additional_artist_ids: [],          # capture…
      additional_manual_names: [],         # capture…
      additional_artist_verified: []
    )

    # Stash for later (create/update) and remove from mass-assignment
    @incoming_additional_ids   = Array(ep.delete(:additional_artist_ids))
    @incoming_additional_names = Array(ep.delete(:additional_manual_names))
    @incoming_additional_verified  = Array(ep.delete(:additional_artist_verified))

    # Translate venue_slug -> venue_id (existing)
    if ep[:venue_slug].present?
      venue = Venue.find_by!(slug: ep.delete(:venue_slug))
      ep[:venue_id] = venue.id
    end

    # Force off cover (existing)
    ep[:cover] = false
    ep[:cover_amount] = nil

    ep
  end

  # Authorization logic
  def authorize_owner_or_admin!
    unless can_modify_event?(@event)
      redirect_to @event, alert: "You don't have permission to modify this event."
    end
  end

  def can_modify_event?(event)
    return false unless event

    # Artist who is performing can modify
    if artist_signed_in? && current_artist == event.artist
      return true
    end

    # Owner of the venue can modify
    if owner_signed_in? && current_owner.venues.include?(event.venue)
      return true
    end

    if promoter_signed_in? && current_promoter.id == event.promoter_id
      return true
    end

    # Admin access
    if user_signed_in? && is_admin?
      return true
    end

    false
  end

  def is_admin?
    return false unless user_signed_in?
    admin_emails = ENV.fetch('ADMIN_EMAILS', 'admin@pickleball.co').split(',').map(&:strip)
    admin_emails.include?(current_user.email)
  end

  def sync_event_artists(event)
    ids   = (@incoming_additional_ids || Array(params.dig(:event, :additional_artist_ids)))
    names = (@incoming_additional_names || Array(params.dig(:event, :additional_manual_names)))
    ver   = (@incoming_additional_verified || Array(params.dig(:event, :additional_artist_verified)))

    ids   = ids.map(&:to_s) # keep as strings for index alignment
    ver   = ver.map(&:to_s)

    # keep only ids whose matching verification index == "1"
    verified_ids = []
    ids.each_with_index do |id, i|
      next if id.blank?
      verified_ids << id.to_i if ver[i].to_s == "1"
    end
    verified_ids.uniq!

    manual_names = names.map { _1.to_s.strip }.reject(&:blank?).uniq

    # Cap at 5 total “additional” (db + manual)
    verified_ids = verified_ids.first(5)
    manual_names = manual_names.first(5 - verified_ids.size)

    existing = event.event_artists.to_a
    keep_keys = verified_ids.map { |id| [:db, id] } + manual_names.map { |n| [:manual, n.downcase] }

    existing.each do |ea|
      key = ea.artist_id.present? ? [:db, ea.artist_id] : [:manual, ea.manual_name.to_s.downcase]
      ea.destroy unless keep_keys.include?(key)
    end

    verified_ids.each_with_index do |aid, idx|
      ea = event.event_artists.find_or_initialize_by(artist_id: aid)
      ea.position = idx
      ea.manual_name = nil
      ea.save! if ea.changed?
    end

    manual_names.each_with_index do |nm, offset|
      pos = verified_ids.size + offset
      ea = event.event_artists.find_or_initialize_by(manual_name: nm)
      ea.position = pos
      ea.artist_id = nil
      ea.save! if ea.changed?
    end
  end
end
