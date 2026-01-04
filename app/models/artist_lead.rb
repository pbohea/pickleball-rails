# == Schema Information
#
# Table name: artist_leads
#
#  id          :bigint           not null, primary key
#  band_name   :string           not null
#  claim_token :string
#  claimed_at  :datetime
#  email       :string           not null
#  source      :string
#  state       :integer          default("unclaimed"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  artist_id   :bigint
#
# Indexes
#
#  index_artist_leads_on_artist_id    (artist_id)
#  index_artist_leads_on_claim_token  (claim_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (artist_id => artists.id)
#
class ArtistLead < ApplicationRecord
  belongs_to :artist, optional: true
  has_many :events

  enum :state, { unclaimed: 0, claimed: 1 }

  validates :band_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_create :generate_claim_token

  def claim_url
    Rails.application.routes.url_helpers.claim_artist_lead_url(claim_token, host: default_host)
  end

  def mark_claimed!(artist)
    update!(state: :claimed, claimed_at: Time.current, artist: artist, claim_token: nil)
  end

  private

  def default_host
    ENV.fetch("APP_HOST", Rails.application.routes.default_url_options[:host])
  end

  def generate_claim_token
    self.claim_token ||= SecureRandom.hex(16)
  end
end
