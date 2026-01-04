class RemoveCategoryFromArtists < ActiveRecord::Migration[8.0]
  def change
    remove_column :artists, :category, :string
  end
end
