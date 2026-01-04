class CreateEventImports < ActiveRecord::Migration[8.0]
  def change
    create_table :event_import_batches do |t|
      t.string   :city, null: false
      t.string   :status, null: false, default: "pending"  # pending|running|finished|failed
      t.integer  :run_by_id
      t.datetime :started_at
      t.datetime :finished_at
      t.text     :notes
      t.timestamps
    end

    create_table :event_import_rows do |t|
      t.references :event_import_batch, null: false, foreign_key: true
      t.integer    :venue_id, null: false
      t.string     :artist_name, null: false
      t.date       :date, null: false
      t.string     :start_time_str, null: false      # keep the raw "HH:MM" string that Claude returns
      t.string     :end_time_str                      # often blank; DO NOT persist to final Event if blank
      t.datetime   :start_time_utc                    # computed for conflict preview
      t.datetime   :end_time_utc                      # computed for conflict preview (3h default if missing)
      t.string     :source_url
      t.jsonb      :raw_json, default: {}
      t.string     :status, null: false, default: "proposed"  # proposed|rejected|approved|created
      t.timestamps
    end

    add_index :event_import_rows, :venue_id
    add_index :event_import_rows, :status
  end
end
