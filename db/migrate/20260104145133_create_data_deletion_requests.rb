class CreateDataDeletionRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :data_deletion_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.datetime :requested_at, null: false
      t.datetime :completed_at
      t.timestamps
    end
  end
end
