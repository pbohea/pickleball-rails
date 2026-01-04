class AddDebugToEventImportBatches < ActiveRecord::Migration[8.0]
  def change
    add_column :event_import_batches, :provider_request_id, :string
    add_column :event_import_batches, :raw_response_json, :jsonb
    add_column :event_import_batches, :tool_names, :string, array: true, default: []
    add_column :event_import_batches, :body_preview, :text
  end
end
