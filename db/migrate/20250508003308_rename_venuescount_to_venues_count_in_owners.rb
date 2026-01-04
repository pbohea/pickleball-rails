class RenameVenuescountToVenuesCountInOwners < ActiveRecord::Migration[8.0]  
  def change
    rename_column :owners, :venuescount, :venues_count
  end
end
