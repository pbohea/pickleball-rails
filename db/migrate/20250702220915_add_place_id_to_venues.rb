class AddPlaceIdToVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :venues, :place_id, :string
    add_index :venues, :place_id
  end
end
