class AddConfirmableToOwners < ActiveRecord::Migration[8.0]
  def change
    add_column :owners, :confirmation_token, :string
    add_column :owners, :confirmed_at, :datetime
    add_column :owners, :confirmation_sent_at, :datetime
    add_column :owners, :unconfirmed_email, :string

    add_index :owners, :confirmation_token, unique: true
  end
end
