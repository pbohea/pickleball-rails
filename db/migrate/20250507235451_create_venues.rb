class CreateVenues < ActiveRecord::Migration[8.0]
  def change
    create_table :venues do |t|
      t.string :address
      t.string :category
      t.integer :events_count
      t.string :name
      t.string :website
      t.integer :owner_id

      t.timestamps
    end
  end
end
