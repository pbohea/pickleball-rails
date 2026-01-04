class RemoveAddressFromVenues < ActiveRecord::Migration[8.0]
  def change
    remove_column :venues, :address, :string
  end
end
