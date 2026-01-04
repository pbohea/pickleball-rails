class ChangeIndoorsDefaultToTrue < ActiveRecord::Migration[7.0]
  def change
    change_column_default :events, :indoors, true
  end
end
