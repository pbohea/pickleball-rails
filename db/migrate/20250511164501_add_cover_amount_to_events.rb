class AddCoverAmountToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :cover_amount, :integer
  end
end
