class RenameArtistLeadStatusToState < ActiveRecord::Migration[7.0]
  def change
    rename_column :artist_leads, :status, :state
  end
end
