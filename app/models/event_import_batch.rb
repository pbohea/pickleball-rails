# app/models/event_import_batch.rb
# == Schema Information
#
# Table name: event_import_batches
#
#  id                  :bigint           not null, primary key
#  body_preview        :text
#  city                :string           not null
#  finished_at         :datetime
#  notes               :text
#  raw_response_json   :jsonb
#  started_at          :datetime
#  status              :string           default("pending"), not null
#  tool_names          :string           default([]), is an Array
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  provider_request_id :string
#  run_by_id           :integer
#
class EventImportBatch < ApplicationRecord
  has_many :event_import_rows, dependent: :destroy
end
