class RemoveFirstnameAndLastnameFromArtistsAndOwners < ActiveRecord::Migration[7.0]
  def change
    remove_column :artists, :firstname, :string
    remove_column :artists, :lastname, :string
    remove_column :owners, :firstname, :string
    remove_column :owners, :lastname, :string
  end
end
