class AddImageToArtist < ActiveRecord::Migration[8.0]
  def change
    add_column :artists, :image, :string
  end
end
