# == Schema Information
#
# Table name: event_artists
#
#  id          :bigint           not null, primary key
#  manual_name :string
#  position    :integer          default(0)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  artist_id   :bigint
#  event_id    :bigint           not null
#
# Indexes
#
#  index_event_artists_on_artist_id                 (artist_id)
#  index_event_artists_on_event_id                  (event_id)
#  index_event_artists_on_event_id_and_artist_id    (event_id,artist_id) UNIQUE WHERE (artist_id IS NOT NULL)
#  index_event_artists_on_event_id_and_manual_name  (event_id,manual_name) UNIQUE WHERE (manual_name IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (artist_id => artists.id)
#  fk_rails_...  (event_id => events.id)
#
class EventArtist < ApplicationRecord
  belongs_to :event
  belongs_to :artist, optional: true

  validates :manual_name, length: { maximum: 140 }, allow_blank: true
  validate  :presence_of_either_side

  scope :ordered, -> { order(:position, :id) }

  def display_name
    artist&.username.presence || manual_name
  end

  private

  def presence_of_either_side
    if artist_id.blank? && manual_name.to_s.strip.blank?
      errors.add(:base, "Choose an artist or enter a name")
    end
  end
end
