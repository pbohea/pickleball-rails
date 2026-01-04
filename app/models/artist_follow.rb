# == Schema Information
#
# Table name: artist_follows
#
#  id            :bigint           not null, primary key
#  follower_type :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  artist_id     :bigint           not null
#  follower_id   :bigint
#
# Indexes
#
#  index_artist_follows_on_artist_id                      (artist_id)
#  index_artist_follows_on_follower_type_and_follower_id  (follower_type,follower_id)
#
# Foreign Keys
#
#  fk_rails_...  (artist_id => artists.id)
#
class ArtistFollow < ApplicationRecord
  belongs_to :follower, polymorphic: true
  belongs_to :artist

  validates :follower_id, uniqueness: { scope: [:artist_id, :follower_type] }
end
