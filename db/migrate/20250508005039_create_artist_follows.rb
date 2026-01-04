class CreateArtistFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :artist_follows do |t|
      t.references :user, null: false, foreign_key: true
      t.references :artist, null: false, foreign_key: true

      t.timestamps
    end
  end
end
