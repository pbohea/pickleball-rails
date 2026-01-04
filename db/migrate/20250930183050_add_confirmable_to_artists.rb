class AddConfirmableToArtists < ActiveRecord::Migration[8.0]
  def change
    add_column :artists, :confirmation_token, :string
    add_column :artists, :confirmed_at, :datetime
    add_column :artists, :confirmation_sent_at, :datetime
    add_column :artists, :unconfirmed_email, :string

    add_index :artists, :confirmation_token, unique: true
  end
end
