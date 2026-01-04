class UpdateNotificationTokensForMultipleUserTypes < ActiveRecord::Migration[8.0]
 def change
   change_column_null :notification_tokens, :user_id, true
   add_reference :notification_tokens, :artist, null: true, foreign_key: true
   add_reference :notification_tokens, :owner, null: true, foreign_key: true
 end
end
