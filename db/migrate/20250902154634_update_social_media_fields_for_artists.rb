class UpdateSocialMediaFieldsForArtists < ActiveRecord::Migration[7.0]
  def change
    # Remove old URL columns
    remove_column :artists, :instagram_url, :string if column_exists?(:artists, :instagram_url)
    remove_column :artists, :youtube_url, :string if column_exists?(:artists, :youtube_url)
    remove_column :artists, :tiktok_url, :string if column_exists?(:artists, :tiktok_url)
    remove_column :artists, :spotify_url, :string if column_exists?(:artists, :spotify_url)

    # Add new username/ID columns
    add_column :artists, :instagram_username, :string
    add_column :artists, :youtube_username, :string
    add_column :artists, :tiktok_username, :string
    add_column :artists, :spotify_artist_id, :string

    # Add indexes for performance if needed
    add_index :artists, :instagram_username
    add_index :artists, :youtube_username
    add_index :artists, :tiktok_username
    add_index :artists, :spotify_artist_id
  end
end
