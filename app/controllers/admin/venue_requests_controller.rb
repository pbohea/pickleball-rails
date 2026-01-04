class Admin::VenueRequestsController < ApplicationController
  before_action :authorize_admin!
  before_action :set_venue_request, only: [:approve, :reject, :update_coordinates]

  def index
    @venue_requests = VenueRequest.order(created_at: :desc)

    if params[:status].present? && VenueRequest.statuses.key?(params[:status])
      @venue_requests = @venue_requests.where(status: params[:status])
    end

    if params[:type].present?
      @venue_requests = @venue_requests.where(request_type: params[:type])
    end

    render template: "admin/index"
  end

  def approve
    venue = @venue_request.approve_and_create_venue!

    if venue
      # Owner-claim push stays conditional (unchanged)
      if @venue_request.ownership_claim? && @venue_request.requester_type == "owner"
        if (owner = Owner.find_by(id: @venue_request.requester_id))
          VenueClaimApprovedNotifier.with(venue_request: @venue_request).deliver(owner)
        end
      end

      # Artist push stays conditional (unchanged)
      if @venue_request.requester_type == "artist"
        if (artist = Artist.find_by(id: @venue_request.requester_id))
          VenueRequestApprovedNotifier.with(venue_request: @venue_request).deliver(artist)
        end
      end

      # 📨 Send email to whoever requested (owner or artist)
      VenueApprovalMailer.venue_approved(@venue_request).deliver_later

      @venue_request.utility_bill.purge_later if @venue_request.utility_bill.attached?
      redirect_to admin_venue_requests_path, notice: "Venue request approved and venue created successfully!"
    else
      redirect_to admin_venue_requests_path, alert: "Failed to approve venue request. Please try again."
    end
  end
  # app/controllers/admin/venue_requests_controller.rb
  def reject
    notes = params[:notes].presence

    if @venue_request.update(status: :rejected, notes: (notes || "Request rejected by admin"))
      # ✉️ Send immediately
      VenueApprovalMailer.venue_request_rejected(@venue_request, notes: notes).deliver_now
      @venue_request.utility_bill.purge_later if @venue_request.utility_bill.attached?
      redirect_to admin_venue_requests_path, notice: "Venue request rejected."
    else
      redirect_to admin_venue_requests_path, alert: "Failed to reject venue request."
    end
  end

  def update_coordinates
    # For existing venue claims, we need to update coordinates AND approve
    if @venue_request.existing_venue_claim?
      venue = @venue_request.existing_venue

      # Update venue details if provided
      if params[:venue_name].present?
        venue.name = params[:venue_name]
      end
      if params[:venue_website].present?
        venue.website = params[:venue_website]
      end

      # Update coordinates if provided
      if params[:latitude].present? && params[:longitude].present?
        venue.latitude = params[:latitude]
        venue.longitude = params[:longitude]
      end

      venue.time_zone = params[:time_zone] if params[:time_zone].present?
      venue.save!

      # Use the model's approve method which handles ownership assignment
      venue = @venue_request.approve_and_create_venue!

      if venue
        # Send notification to owner if it's an ownership claim
        if @venue_request.ownership_claim? && @venue_request.requester_type == "owner"
          owner = Owner.find_by(id: @venue_request.requester_id)
          if owner
            VenueClaimApprovedNotifier.with(venue_request: @venue_request).deliver(owner)
            VenueApprovalMailer.venue_approved(@venue_request).deliver_now
          end
        end

        if @venue_request.requester_type == "artist"
          artist = Artist.find_by(id: @venue_request.requester_id)
          VenueRequestApprovedNotifier.with(venue_request: @venue_request).deliver(artist) if artist
        end
        @venue_request.utility_bill.purge_later if @venue_request.utility_bill.attached?
        redirect_to admin_venue_requests_path, notice: "Coordinates updated and venue ownership assigned."
      else
        redirect_to admin_venue_requests_path, alert: "Failed to approve venue request."
      end
    else
      # For new venue requests - USE THE EDITED FORM VALUES
      venue = Venue.new(
        name: params[:venue_name] || @venue_request.name,
        street_address: params[:venue_street_address] || @venue_request.street_address,
        city: params[:venue_city] || @venue_request.city,
        state: params[:venue_state] || @venue_request.state,
        zip_code: params[:venue_zip_code] || @venue_request.zip_code,
        website: params[:venue_website] || @venue_request.website,
        category: params[:venue_category] || @venue_request.category,
        latitude: params[:latitude],
        longitude: params[:longitude],
        time_zone: params[:time_zone],
      )

      venue.skip_geocoding = true

      if venue.save
          venue.update!(owner_id: @venue_request.requester_id) if @venue_request.ownership_claim? && @venue_request.requester_type == "owner"

          @venue_request.update(status: :approved, venue_id: venue.id)

          if @venue_request.ownership_claim? && @venue_request.requester_type == "owner"
            if (owner = Owner.find_by(id: @venue_request.requester_id))
              VenueClaimApprovedNotifier.with(venue_request: @venue_request).deliver(owner)
            end
          end
          if @venue_request.requester_type == "artist"
            if (artist = Artist.find_by(id: @venue_request.requester_id))
              VenueRequestApprovedNotifier.with(venue_request: @venue_request).deliver(artist)
            end
          end

          # 📨 Always send the email on approval (owner or artist)
          VenueApprovalMailer.venue_approved(@venue_request).deliver_later

          @venue_request.utility_bill.purge_later if @venue_request.utility_bill.attached?
          redirect_to admin_venue_requests_path, notice: "Venue created with your edits and approved."
        else
          redirect_to admin_venue_requests_path, alert: "Failed to save venue: #{venue.errors.full_messages.join(", ")}"
        end
      end
  end

  private

  def set_venue_request
    @venue_request = VenueRequest.find(params[:id])
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
