class CreateArtistLeads < ActiveRecord::Migration[7.0]
  def change
    create_table :artist_leads do |t|
      t.string :band_name, null: false
      t.string :email, null: false
      t.integer :status, null: false, default: 0
      t.string :claim_token
      t.datetime :claimed_at
      t.references :artist, foreign_key: true, null: true
      t.string :source

      t.timestamps
    end

    add_index :artist_leads, :claim_token, unique: true

    add_reference :events, :artist_lead, null: true, foreign_key: true
  end
end
