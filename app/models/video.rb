# == Schema Information
#
# Table name: videos
#
#  id           :bigint           not null, primary key
#  notes        :text
#  processed_at :datetime
#  source       :integer          default("camera"), not null
#  status       :integer          default("uploaded"), not null
#  title        :string
#  uploaded_at  :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_videos_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Video < ApplicationRecord
  belongs_to :user

  has_one_attached :original_video
  has_one_attached :processed_video

  has_many :analyses, dependent: :destroy
  has_one :conversation, dependent: :destroy

  enum :source, { camera: 0, library: 1 }
  enum :status, { uploaded: 0, processing: 1, analyzed: 2, failed: 3 }

  validates :source, presence: true
  validates :status, presence: true
end
