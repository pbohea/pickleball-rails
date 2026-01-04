# app/controllers/admin/venues_controller.rb
class Admin::VenuesController < ApplicationController
  before_action :authorize_admin!
  before_action :set_venue, only: %i[
                              show edit update destroy
                              edit_owner update_owner remove_owner
                            ]

  # GET /admin/venues
  # Filters: ?owned=owned|unowned|all  and ?q=search
  def index
    @owned_filter = case params[:owned].to_s
      when "owned", "unowned" then params[:owned]
      else "all"
      end
    @q = params[:q].to_s.strip

    scope = Venue.includes(:owner)

    scope = case @owned_filter
      when "owned" then scope.where.not(owner_id: nil)
      when "unowned" then scope.where(owner_id: nil)
      else scope
      end

    if @q.present?
      scope = scope.where(
        "venues.name ILIKE :q OR venues.city ILIKE :q OR venues.state ILIKE :q OR venues.zip_code ILIKE :q OR venues.website ILIKE :q",
        q: "%#{@q}%",
      )
    end

    @venues = scope.order(:name)
  end

  def show; end

  def new
    @venue = Venue.new
  end

  def create
    @venue = Venue.new(venue_params) # (no owner assignment here)

    @venue.skip_geocoding = true

    if @venue.save
      # redirect_to admin_venue_path(@venue), notice: "Venue created."
      redirect_to admin_dashboard_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @venue.update(venue_params) # (no owner updates here)
      redirect_to admin_venue_path(@venue), notice: "Venue updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @venue.destroy!
    redirect_to admin_venues_path, notice: "Venue deleted."
  end

  # --- Owner management ---

  # GET /admin/venues/:id/edit_owner
  def edit_owner
    # just renders form
  end

  # PATCH /admin/venues/:id/update_owner
  def update_owner
    old_owner = @venue.owner
    new_owner_id = params[:owner_id].presence
    new_owner = new_owner_id.present? ? Owner.find_by(id: new_owner_id) : nil

    unless new_owner || new_owner_id.nil?
      flash.now[:alert] = "New owner not found."
      return render :edit_owner, status: :unprocessable_entity
    end

    if @venue.update(owner_id: new_owner_id)
      # Email notifications only if assigning (and changed)
      if new_owner.present? && old_owner != new_owner
        # Notify new owner
        VenueOwnershipMailer.assigned_to_new_owner(
          venue: @venue, new_owner: new_owner, old_owner: old_owner,
        ).deliver_now

        # Notify previous owner, if there was one
        if old_owner.present?
          VenueOwnershipMailer.reassigned_from_old_owner(
            venue: @venue, old_owner: old_owner, new_owner: new_owner,
          ).deliver_now
        end
      end

      redirect_to edit_owner_admin_venue_path(@venue),
                  notice: (new_owner ? "Owner reassigned." : "Owner cleared.")
    else
      flash.now[:alert] = @venue.errors.full_messages.to_sentence
      render :edit_owner, status: :unprocessable_entity
    end
  end

  # DELETE /admin/venues/:id/remove_owner
  def remove_owner
    old_owner = @venue.owner

    if @venue.update(owner_id: nil)
      if old_owner.present?
        VenueOwnershipMailer.ownership_removed_from_owner(
          venue: @venue, old_owner: old_owner,
        ).deliver_now
      end

      redirect_to edit_owner_admin_venue_path(@venue), notice: "Owner removed."
    else
      flash.now[:alert] = @venue.errors.full_messages.to_sentence
      render :edit_owner, status: :unprocessable_entity
    end
  end

  private

  def set_venue
    @venue = Venue.find_by!(slug: params[:id])
  end

  def venue_params
    params.require(:venue).permit(
      :name, :category, :website,
      :street_address, :city, :state, :zip_code,
      :latitude, :longitude, :time_zone, :image, :scrapable
    )
  end

  def authorize_admin!
    unless is_admin?
      redirect_to root_path, alert: "You don't have permission to access this page."
    end
  end

  def is_admin?
    return false unless user_signed_in?
    admin_emails = ENV.fetch('ADMIN_EMAILS', 'admin@pickleball.co').split(',').map(&:strip)
    admin_emails.include?(current_user.email)
  end
end
