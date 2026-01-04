class CreateEventArtists < ActiveRecord::Migration[8.0]
  def change
    create_table :event_artists do |t|
      t.references :event, null: false, foreign_key: true
      t.references :artist, null: true, foreign_key: true  # null when manual name
      t.string :manual_name                               # present when manual
      t.integer :position, default: 0                     # lineup order
      t.timestamps
    end

    add_index :event_artists, [:event_id, :artist_id], unique: true, where: "artist_id IS NOT NULL"
    add_index :event_artists, [:event_id, :manual_name], unique: true, where: "manual_name IS NOT NULL"
  end
end
