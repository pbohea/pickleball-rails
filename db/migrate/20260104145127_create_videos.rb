class CreateVideos < ActiveRecord::Migration[7.1]
  def change
    create_table :videos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :notes
      t.integer :source, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :uploaded_at
      t.datetime :processed_at
      t.timestamps
    end
  end
end
