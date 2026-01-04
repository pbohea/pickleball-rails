class CreateVenueRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :venue_requests do |t|
      t.string :name, null: false
      t.string :street_address, null: false
      t.string :city, null: false
      t.string :state, null: false, limit: 2
      t.string :zip_code, null: false, limit: 10
      t.string :website
      t.string :category, null: false
      t.string :requester_type, null: false
      t.integer :requester_id, null: false
      t.integer :status, default: 0, null: false
      t.integer :venue_id
      t.text :notes
      
      # Owner-specific fields
      t.boolean :ownership_claim, default: false, null: false
      t.string :owner_phone
      
      t.timestamps
    end

    add_index :venue_requests, [:requester_type, :requester_id]
    add_index :venue_requests, :status
    add_index :venue_requests, :ownership_claim
    add_index :venue_requests, :venue_id
  end
end
