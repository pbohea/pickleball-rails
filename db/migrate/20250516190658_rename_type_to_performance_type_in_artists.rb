class RenameTypeToPerformanceTypeInArtists < ActiveRecord::Migration[8.0]
  def change
    rename_column :artists, :type, :performance_type
  end
end
