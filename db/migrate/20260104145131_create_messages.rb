class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.integer :role, null: false, default: 0
      t.text :content, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :messages, [:conversation_id, :created_at]
  end
end
