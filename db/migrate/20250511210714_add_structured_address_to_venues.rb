class AddStructuredAddressToVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :venues, :street_address, :string
    add_column :venues, :city, :string
    add_column :venues, :state, :string
    add_column :venues, :zip_code, :string
  end
end
