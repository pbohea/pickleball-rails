class CreateConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :video, null: false, foreign_key: true
      t.references :analysis, foreign_key: true
      t.timestamps
    end

    add_index :conversations, :video_id, unique: true unless index_exists?(:conversations, :video_id)
  end
end
