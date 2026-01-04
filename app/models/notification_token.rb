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
  belongs_to :user, optional: true
  belongs_to :artist, optional: true
  belongs_to :owner, optional: true
  
  validates :token, presence: true
  validates :platform, inclusion: {in: %w[iOS]}
  
  # Ensure at least one user type is present
  validate :must_have_at_least_one_user_type
  
  private
  
  def must_have_at_least_one_user_type
    if user_id.blank? && artist_id.blank? && owner_id.blank?
      errors.add(:base, "Must belong to at least one user type")
    end
  end
end
