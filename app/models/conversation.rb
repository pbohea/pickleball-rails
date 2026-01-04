# == Schema Information
#
# Table name: conversations
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  analysis_id :bigint
#  user_id     :bigint           not null
#  video_id    :bigint           not null
#
# Indexes
#
#  index_conversations_on_analysis_id  (analysis_id)
#  index_conversations_on_user_id      (user_id)
#  index_conversations_on_video_id     (video_id)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_id => analyses.id)
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (video_id => videos.id)
#
class Conversation < ApplicationRecord
  belongs_to :user
  belongs_to :video
  belongs_to :analysis, optional: true

  has_many :messages, dependent: :destroy
end
