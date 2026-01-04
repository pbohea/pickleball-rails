class CreateAnalyses < ActiveRecord::Migration[7.1]
  def change
    create_table :analyses do |t|
      t.references :video, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.string :model_version
      t.jsonb :cv_results, null: false, default: {}
      t.text :summary
      t.timestamps
    end

    add_index :analyses, [:video_id, :created_at]
  end
end
