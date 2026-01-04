# == Schema Information
#
# Table name: venue_follows
#
#  id            :bigint           not null, primary key
#  follower_type :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  follower_id   :bigint
#  venue_id      :bigint           not null
#
# Indexes
#
#  index_venue_follows_on_follower_type_and_follower_id  (follower_type,follower_id)
#  index_venue_follows_on_venue_id                       (venue_id)
#
# Foreign Keys
#
#  fk_rails_...  (venue_id => venues.id)
#
class VenueFollow < ApplicationRecord
  belongs_to :follower, polymorphic: true
  belongs_to :venue

  validates :follower_id, uniqueness: { scope: [:venue_id, :follower_type] }
end
