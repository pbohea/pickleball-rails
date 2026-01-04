class ChangeVenueFollowsToPolymorphic < ActiveRecord::Migration[8.0]
  def up
    # Add polymorphic columns
    add_column :venue_follows, :follower_type, :string
    add_column :venue_follows, :follower_id, :bigint
    
    # Migrate existing data
    VenueFollow.reset_column_information
    VenueFollow.where(follower_type: nil).update_all(follower_type: 'User')
    VenueFollow.where(follower_id: nil).each do |follow|
      follow.update!(follower_id: follow.user_id)
    end
    
    # Add index and remove old columns
    add_index :venue_follows, [:follower_type, :follower_id]
    remove_column :venue_follows, :user_id
    remove_index :venue_follows, :index_venue_follows_on_user_id if index_exists?(:venue_follows, :user_id)
  end

  def down
    add_column :venue_follows, :user_id, :bigint
    
    VenueFollow.reset_column_information
    VenueFollow.where(follower_type: 'User').each do |follow|
      follow.update!(user_id: follow.follower_id)
    end
    
    remove_column :venue_follows, :follower_type
    remove_column :venue_follows, :follower_id
    add_index :venue_follows, :user_id
  end
end
