class CreateAnalysisEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :analysis_events do |t|
      t.references :analysis, null: false, foreign_key: true
      t.bigint :timestamp_ms, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    add_index :analysis_events, [:analysis_id, :timestamp_ms]
  end
end
