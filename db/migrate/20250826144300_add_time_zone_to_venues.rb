class AddTimeZoneToVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :venues, :time_zone, :string
  end
end
