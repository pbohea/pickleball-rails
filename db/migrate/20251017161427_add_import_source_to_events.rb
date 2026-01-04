class AddImportSourceToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :import_source, :string
    add_index :events, :import_source
  end
end
