class CreateVenueFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :venue_follows do |t|
      t.references :user, null: false, foreign_key: true
      t.references :venue, null: false, foreign_key: true

      t.timestamps
    end
  end
end
