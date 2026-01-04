# app/mailers/venue_approval_mailer.rb
class VenueApprovalMailer < ApplicationMailer
    def venue_approved(venue_request)
    @venue_request = venue_request

    # Resolve the approved venue (works for new venue or existing claim)
    @venue = if venue_request.venue_id.present?
      Venue.find_by(id: venue_request.venue_id)
    else
      venue_request.existing_venue
    end

    # Resolve recipient (owner OR artist), but keep @owner for backward-compatible views
    @recipient =
      case venue_request.requester_type
      when "owner"
        @owner = Owner.find_by(id: venue_request.requester_id)
      when "artist"
        @artist = Artist.find_by(id: venue_request.requester_id)
      when "promoter"
        @promoter = Promoter.find_by(id: venue_request.requester_id)
      end

    # Bail out unless we have someone to email and a venue to link to
    return unless @recipient&.email.present? && @venue.present?

    # Generate venue page URL
    @venue_url = venue_url(@venue)

    # Subject tailored to request type; keeps old text for claims
    subject_line =
      if venue_request.existing_venue_claim?
        "Your Pickleball venue claim has been approved!"
      else
        "Your Pickleball venue request has been approved!"
      end

    mail(
      to: @recipient.email,
      subject: subject_line,
    )
  end

  def venue_request_rejected(venue_request, notes: nil)
    @venue_request = venue_request
    @notes = notes.presence

    recipient = case venue_request.requester_type
      when "owner" then Owner.find_by(id: venue_request.requester_id)
      when "artist" then Artist.find_by(id: venue_request.requester_id)
      when "promoter" then Promoter.find_by(id: venue_request.requester_id)
      end
    return unless recipient&.email.present?

    mail(
      to: recipient.email,
      subject: "Your Pickleball venue request was rejected",
    )
  end

  def new_venue_request_notification(venue_request)
    @venue_request = venue_request
    @requester = if venue_request.requester_type == "owner"
                  Owner.find_by(id: venue_request.requester_id)
                elsif venue_request.requester_type == "artist"
                  Artist.find_by(id: venue_request.requester_id)
                elsif venue_request.requester_type == "promoter"
                  Promoter.find_by(id: venue_request.requester_id)
                end
    
    @request_type_display = case venue_request.request_type
                          when "new_venue"
                            "New Venue Request"
                          when "existing_venue_claim"
                            "Venue Ownership Claim"
                          else
                            "Venue Request"
                          end

    mail(
      to: "admin@pickleball.co",
      subject: "#{@request_type_display} - #{venue_request.name}"
    )
  end


end
