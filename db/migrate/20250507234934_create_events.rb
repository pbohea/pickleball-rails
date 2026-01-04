class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string :category
      t.boolean :cover
      t.date :date
      t.string :description
      t.datetime :start_time
      t.datetime :end_time
      t.boolean :indoors
      t.integer :artist_id
      t.integer :venue_id

      t.timestamps
    end
  end
end
