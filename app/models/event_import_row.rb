# app/models/event_import_row.rb
# == Schema Information
#
# Table name: event_import_rows
#
#  id                    :bigint           not null, primary key
#  artist_name           :string           not null
#  date                  :date             not null
#  end_time_str          :string
#  end_time_utc          :datetime
#  raw_json              :jsonb
#  source_url            :string
#  start_time_str        :string           not null
#  start_time_utc        :datetime
#  status                :string           default("proposed"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  event_import_batch_id :bigint           not null
#  venue_id              :integer          not null
#
# Indexes
#
#  index_event_import_rows_on_event_import_batch_id  (event_import_batch_id)
#  index_event_import_rows_on_status                 (status)
#  index_event_import_rows_on_venue_id               (venue_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_import_batch_id => event_import_batches.id)
#
class EventImportRow < ApplicationRecord
  belongs_to :event_import_batch
  belongs_to :venue

  scope :proposed, -> { where(status: "proposed") }
end
