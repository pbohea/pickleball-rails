class AddCategoryToArtists < ActiveRecord::Migration[8.0]
  def change
    add_column :artists, :category, :string
  end
end
