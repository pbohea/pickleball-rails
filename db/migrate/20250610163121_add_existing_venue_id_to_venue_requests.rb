class AddExistingVenueIdToVenueRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :venue_requests, :existing_venue_id, :integer
    add_column :venue_requests, :request_type, :string
  end
end
