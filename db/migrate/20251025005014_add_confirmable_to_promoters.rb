class AddConfirmableToPromoters < ActiveRecord::Migration[7.2]
  def change
    add_column :promoters, :confirmation_token, :string
    add_column :promoters, :confirmed_at, :datetime
    add_column :promoters, :confirmation_sent_at, :datetime
    add_column :promoters, :unconfirmed_email, :string
    add_index  :promoters, :confirmation_token, unique: true
  end
end
