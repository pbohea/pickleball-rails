# == Schema Information
#
# Table name: data_export_requests
#
#  id           :bigint           not null, primary key
#  completed_at :datetime
#  requested_at :datetime         not null
#  status       :integer          default("requested"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_data_export_requests_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class DataExportRequest < ApplicationRecord
  belongs_to :user

  has_one_attached :export_file

  enum :status, { requested: 0, processing: 1, ready: 2, failed: 3 }

  validates :status, presence: true
  validates :requested_at, presence: true
end
