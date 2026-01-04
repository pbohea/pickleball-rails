class ChangeArtistFollowsToPolymorphic < ActiveRecord::Migration[8.0]
  def up
    # Add polymorphic columns
    add_column :artist_follows, :follower_type, :string
    add_column :artist_follows, :follower_id, :bigint
    
    # Migrate existing data
    ArtistFollow.reset_column_information
    ArtistFollow.where(follower_type: nil).update_all(follower_type: 'User')
    ArtistFollow.where(follower_id: nil).each do |follow|
      follow.update!(follower_id: follow.user_id)
    end
    
    # Add index and remove old columns
    add_index :artist_follows, [:follower_type, :follower_id]
    remove_column :artist_follows, :user_id
    remove_index :artist_follows, :index_artist_follows_on_user_id if index_exists?(:artist_follows, :user_id)
  end

  def down
    add_column :artist_follows, :user_id, :bigint
    
    ArtistFollow.reset_column_information
    ArtistFollow.where(follower_type: 'User').each do |follow|
      follow.update!(user_id: follow.follower_id)
    end
    
    remove_column :artist_follows, :follower_type
    remove_column :artist_follows, :follower_id
    add_index :artist_follows, :user_id
  end
end
