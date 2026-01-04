class ArtistLeadsController < ApplicationController
  def new
    @artist_lead = ArtistLead.new(source: params[:source])
  end

  def create
    @artist_lead = ArtistLead.new(artist_lead_params)

    if @artist_lead.save
      redirect_to new_artist_registration_path(
        artist_lead_token: @artist_lead.claim_token,
        username: @artist_lead.band_name,
        email: @artist_lead.email
      )
    else
      render :new, status: :unprocessable_entity
    end
  end

  def claim
    @artist_lead = ArtistLead.find_by(claim_token: params[:token])

    if @artist_lead.nil?
      redirect_to new_artist_registration_path, alert: "That claim link is invalid or has expired."
      return
    end

    if @artist_lead.claimed?
      redirect_to new_artist_session_path, notice: "This lead is already claimed. Sign in to continue."
      return
    end

    redirect_to new_artist_registration_path(
      artist_lead_token: @artist_lead.claim_token,
      username: @artist_lead.band_name,
      email: @artist_lead.email
    )
  end

  def thank_you
  end

  private

  def artist_lead_params
    params.require(:artist_lead).permit(:band_name, :email, :source)
  end
end
