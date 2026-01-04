class VenueRequestsController < ApplicationController
  before_action :authenticate_user_or_artist_or_owner!, only: [:new, :create, :claim, :receipt, :destroy]

  def new
    @venue_request = VenueRequest.new
  end

  def claim
      # Only allow venue owners to access this
      if owner_signed_in?
        # Proceed to render the claim form
        return
      elsif artist_signed_in?
        redirect_to artist_dashboard_path, alert: "Only venue owners can claim venues."
      elsif promoter_signed_in?
        redirect_to promoter_dashboard_path, alert: "Only venue owners can claim venues"
      elsif user_signed_in?
        redirect_to user_dashboard_path, alert: "Only venue owners can claim venues."
      else
        redirect_to new_owner_session_path, alert: "You must sign in as an owner to claim a venue."
      end
    end

    def create
    @venue_request = VenueRequest.new(venue_request_params)

    if artist_signed_in?
      # Artists can only request NEW venues
      @venue_request.requester_type   = "artist"
      @venue_request.requester_id     = current_artist.id
      @venue_request.ownership_claim  = false
      @venue_request.request_type     = "new_venue"

    elsif owner_signed_in?
      # Owners can request NEW venues OR claim an existing venue
      @venue_request.requester_type   = "owner"
      @venue_request.requester_id     = current_owner.id
      @venue_request.ownership_claim  = true

      slug_or_id = params[:existing_venue_slug].presence || params[:existing_venue_id].presence

      if slug_or_id.present?
        @venue_request.request_type = "existing_venue_claim"

        venue = if slug_or_id.to_s =~ /\A\d+\z/
          Venue.find_by(id: slug_or_id.to_i)
        else
          Venue.find_by(slug: slug_or_id)
        end

        unless venue
          @venue_request.errors.add(:base, "We couldn't find that venue. Please re-select it.")
          return render :claim, status: :unprocessable_entity
        end

        # store canonical id and copy snapshot fields
        @venue_request.existing_venue_id = venue.id
        @venue_request.name          = venue.name
        @venue_request.street_address = venue.street_address
        @venue_request.city          = venue.city
        @venue_request.state         = venue.state
        @venue_request.zip_code      = venue.zip_code
        @venue_request.website       = venue.website
        @venue_request.category      = venue.category
      else
        @venue_request.request_type = "new_venue"
      end

    elsif promoter_signed_in?
      # Promoters can only request NEW venues (no ownership)
      @venue_request.requester_type   = "promoter"
      @venue_request.requester_id     = current_promoter.id
      @venue_request.ownership_claim  = false
      @venue_request.request_type     = "new_venue"

    else
      return redirect_to root_path, alert: "You must be signed in."
    end

    if @venue_request.save
      VenueApprovalMailer.new_venue_request_notification(@venue_request).deliver_now
      redirect_to receipt_venue_request_path(@venue_request)
    else
      Rails.logger.error "[VenueRequests] Save failed: #{@venue_request.errors.full_messages.join(', ')}"
      if params[:existing_venue_slug].present? || params[:existing_venue_id].present?
        render :claim, status: :unprocessable_entity
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @venue_request = VenueRequest.find(params[:id])

    # Security check - only the requester can cancel their own request
    if @venue_request.requester_type == "owner" && current_owner && @venue_request.requester_id != current_owner.id
      redirect_to root_path, alert: "You don't have permission to cancel this request." and return
    elsif @venue_request.requester_type == "artist" && current_artist && @venue_request.requester_id != current_artist.id
      redirect_to root_path, alert: "You don't have permission to cancel this request." and return
    elsif @venue_request.requester_type == "promoter" && current_promoter && @venue_request.requester_id != current_promoter.id
      redirect_to root_path, alert: "You don't have permission to cancel this request." and return
    elsif !current_owner && !current_artist && !current_promoter
      redirect_to root_path, alert: "You must be signed in to cancel this request." and return
    end

    # Only allow canceling pending requests
    unless @venue_request.pending?
      redirect_back(fallback_location: root_path, alert: "You can only cancel pending requests.")
      return
    end

    if @venue_request.destroy
      redirect_back(fallback_location: root_path, notice: "Venue request has been canceled.")
    else
      redirect_back(fallback_location: root_path, alert: "Unable to cancel the request. Please try again.")
    end
  end

  def receipt
    @venue_request = VenueRequest.find(params[:id])

    # Security check - only the requester should see their receipt
    if @venue_request.requester_type == "owner" && current_owner && @venue_request.requester_id != current_owner.id
      redirect_to root_path, alert: "You don't have permission to view this receipt." and return
    elsif @venue_request.requester_type == "artist" && current_artist && @venue_request.requester_id != current_artist.id
      redirect_to root_path, alert: "You don't have permission to view this receipt." and return
    elsif @venue_request.requester_type == "promoter" && current_promoter && @venue_request.requester_id != current_promoter.id
      redirect_to root_path, alert: "You don't have permission to view this receipt." and return
    elsif !current_owner && !current_artist && !current_promoter
      redirect_to root_path, alert: "You must be signed in to view this receipt." and return
    end

    # Render different templates based on request type AND user type
    if @venue_request.existing_venue_claim?
      render :claim_receipt  # Only owners can claim
    elsif @venue_request.requester_type == "owner"
      render :new_venue_receipt_owner
    elsif @venue_request.requester_type == "artist"
      render :new_venue_receipt_artist
    elsif @venue_request.requester_type == "promoter"
      render :new_venue_receipt_promoter
    else
      render :new_venue_receipt_owner  # fallback
    end
  end

  private

  def venue_request_params
    params.require(:venue_request).permit(
      :name, :street_address, :city, :state, :zip_code,
      :website, :category, :owner_phone, :utility_bill
    )
  end

  def authenticate_user_or_artist_or_owner!
    unless user_signed_in? || artist_signed_in? || owner_signed_in? || promoter_signed_in?
      redirect_to root_path, alert: "You must be signed in."
    end
  end
end
