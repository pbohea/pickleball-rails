class ArtistLeadMailer < ApplicationMailer
  def claim_email
    @artist_lead = params[:artist_lead]
    return if @artist_lead.blank?

    @claim_url = claim_artist_lead_url(@artist_lead.claim_token)

    mail(
      to: @artist_lead.email,
      subject: "Claim your artist profile on Pickleball"
    )
  end
end
