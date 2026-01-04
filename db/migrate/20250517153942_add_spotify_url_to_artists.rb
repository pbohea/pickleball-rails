class AddSpotifyUrlToArtists < ActiveRecord::Migration[8.0]
  def change
    add_column :artists, :spotify_url, :string
  end
end
