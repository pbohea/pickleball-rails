class AddTypeToArtists < ActiveRecord::Migration[8.0]
  def change
    add_column :artists, :type, :string
  end
end
