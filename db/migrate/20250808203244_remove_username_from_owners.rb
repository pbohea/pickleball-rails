class RemoveUsernameFromOwners < ActiveRecord::Migration[8.0]
  def change
    remove_column :owners, :username, :string
  end
end
