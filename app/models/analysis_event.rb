# == Schema Information
#
# Table name: analysis_events
#
#  id           :bigint           not null, primary key
#  event_type   :string           not null
#  payload      :jsonb            not null
#  timestamp_ms :bigint           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  analysis_id  :bigint           not null
#
# Indexes
#
#  index_analysis_events_on_analysis_id                   (analysis_id)
#  index_analysis_events_on_analysis_id_and_timestamp_ms  (analysis_id,timestamp_ms)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_id => analyses.id)
#
class AnalysisEvent < ApplicationRecord
  belongs_to :analysis

  validates :timestamp_ms, presence: true
  validates :event_type, presence: true
end
