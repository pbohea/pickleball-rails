class AddArtistNameToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :artist_name, :string
  end
end
