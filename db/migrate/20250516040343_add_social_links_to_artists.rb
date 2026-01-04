class AddSocialLinksToArtists < ActiveRecord::Migration[8.0]
  def change
    add_column :artists, :instagram_url, :string
    add_column :artists, :youtube_url, :string
    add_column :artists, :tiktok_url, :string
  end
end
