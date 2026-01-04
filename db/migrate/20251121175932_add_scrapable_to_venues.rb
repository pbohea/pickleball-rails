class AddScrapableToVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :venues, :scrapable, :boolean, default: false, null: false
  end
end
