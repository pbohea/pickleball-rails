# == Schema Information
#
# Table name: notification_tokens
#
#  id         :bigint           not null, primary key
#  platform   :string           not null
#  token      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  artist_id  :bigint
#  owner_id   :bigint
#  user_id    :bigint
#
# Indexes
#
#  index_notification_tokens_on_artist_id  (artist_id)
#  index_notification_tokens_on_owner_id   (owner_id)
#  index_notification_tokens_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (artist_id => artists.id)
#  fk_rails_...  (owner_id => owners.id)
#  fk_rails_...  (user_id => users.id)
#
class NotificationToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: { scope: :user_id }
  validates :platform, presence: true
end
