class AddPromoterToEvents < ActiveRecord::Migration[7.2]
  def change
    add_reference :events, :promoter, foreign_key: true, index: true
  end
end
