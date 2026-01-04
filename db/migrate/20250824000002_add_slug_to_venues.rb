class AddSlugToVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :venues, :slug, :string
    add_index :venues, :slug, unique: true
  end
end