class AddBioToArtists < ActiveRecord::Migration[8.0]
  def change
    add_column :artists, :bio, :text
  end
end
