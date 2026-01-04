class VenuesController < ApplicationController
  before_action :set_venue, only: %i[ show edit update destroy ]
  before_action :authenticate_user!, only: %i[ edit update destroy ]
  before_action :authorize_venue_access!, only: %i[ edit update destroy ]
  helper_method :is_admin?

  # GET /venues or /venues.json
  def index
    @venues = Venue.all
  end

  # GET /venues/1 or /venues/1.json
  def show
    @upcoming_events = @venue.events
                             .upcoming
                             .includes(:venue, :artist, additional_artists: [])
    @past_events     = @venue.events
                             .past
                             .includes(:venue, :artist, additional_artists: [])
                             .limit(10)

    respond_to do |format|
      format.html do
        if turbo_frame_request?
          render partial: "venues/show", locals: { venue: @venue }
        else
          render :show
        end
      end
    end
  end

  # GET /venues/new
  def new
    @venue = Venue.new
  end

  # app/controllers/venues_controller.rb
  def search
    raw = params[:query].to_s.strip
    return render json: [] if raw.blank?

    # Normalize curly quotes to straight, downcase
    normalized = raw.tr("’‘`´‵‶′", "'").downcase

    # Tokenize (supports "hideaway dallas", "dallas hideaway", etc.)
    tokens = normalized.split(/\s+/).uniq
    sanitize_like = ->(s) { ActiveRecord::Base.sanitize_sql_like(s) }

    # SQL expressions with punctuation/diacritic normalization
    # Requires the unaccent extension (see migration below)
    name_expr = "LOWER(unaccent(translate(name,  '’‘`´‵‶′', '''''''')))"
    city_expr = "LOWER(unaccent(translate(city,  '’‘`´‵‶′', '''''''')))"

    # Build: (name LIKE ? OR city LIKE ?) AND (name LIKE ? OR city LIKE ?) ...
    where_sql = tokens.map { "(#{name_expr} LIKE ? OR #{city_expr} LIKE ?)" }.join(" AND ")
    binds = tokens.flat_map { |t| pat = "%#{sanitize_like.call(t)}%"; [pat, pat] }

    venues = Venue
      .where(where_sql, *binds)
      .select(:id, :slug, :name, :street_address, :city, :state, :zip_code, :website)
      .order(Arel.sql("#{name_expr} ASC, #{city_expr} ASC"))
      .limit(10)

    render json: venues
  end

  # GET /venues/1/edit
  def edit
  end

  # POST /venues or /venues.json
  def create
    @venue = current_owner.venues.build(venue_params)

    respond_to do |format|
      if @venue.save
        format.html { redirect_to @venue, notice: "Venue was successfully created." }
        format.json { render :show, status: :created, location: @venue }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @venue.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /venues/1 or /venues/1.json
  def update
    respond_to do |format|
      if @venue.update(venue_params)
        format.html { redirect_to @venue, notice: "Venue was successfully updated." }
        format.json { render :show, status: :ok, location: @venue }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @venue.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @venue.destroy!

    respond_to do |format|
      format.html { redirect_to venues_path, status: :see_other, notice: "Venue was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def upcoming_events
    @venue = Venue.find(params[:id])
    @events = @venue.events.upcoming

    render partial: "venues/upcoming_events", locals: { venue: @venue, events: @events }, layout: false
  end

  def check_ownership
    @venue = Venue.find_by!(slug: params[:id])
    render json: {
             has_owner: @venue.owner_id.present?,
             venue_id: @venue.id,
           }
  end

  private

  def set_venue
    @venue = Venue.find_by!(slug: params.expect(:id))
    #@venue = Venue.find_by!(slug: params[:id])
  end

  def venue_params
    permitted = [
      :name,
      :category,
      :website,
      :street_address,
      :city,
      :state,
      :zip_code,
      :latitude,
      :longitude,
      :image
    ]

    # Only admins can set scrapable
    permitted << :scrapable if is_admin?

    params.require(:venue).permit(*permitted)
  end

  def is_admin?
    return false unless user_signed_in?
    admin_emails = ENV.fetch('ADMIN_EMAILS', 'admin@pickleball.co').split(',').map(&:strip)
    admin_emails.include?(current_user.email)
  end

  def authorize_venue_access!
    return if is_admin?

    # Check if user is the owner
    if current_user.is_a?(Owner) && @venue.owner_id == current_user.id
      return
    end

    # Not authorized
    redirect_to root_path, alert: "You don't have permission to edit this venue."
  end
end
