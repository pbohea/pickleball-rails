# == Schema Information
#
# Table name: analyses
#
#  id            :bigint           not null, primary key
#  completed_at  :datetime
#  cv_results    :jsonb            not null
#  model_version :string
#  started_at    :datetime
#  status        :integer          default("pending"), not null
#  summary       :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  video_id      :bigint           not null
#
# Indexes
#
#  index_analyses_on_video_id                 (video_id)
#  index_analyses_on_video_id_and_created_at  (video_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (video_id => videos.id)
#
class Analysis < ApplicationRecord
  belongs_to :video

  has_many :analysis_events, dependent: :destroy
  has_one :conversation, dependent: :nullify

  enum :status, { pending: 0, running: 1, complete: 2, failed: 3 }

  validates :status, presence: true
end
