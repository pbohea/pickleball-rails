# == Schema Information
#
# Table name: messages
#
#  id              :bigint           not null, primary key
#  content         :text             not null
#  metadata        :jsonb            not null
#  role            :integer          default("user"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :bigint           not null
#
# Indexes
#
#  index_messages_on_conversation_id                 (conversation_id)
#  index_messages_on_conversation_id_and_created_at  (conversation_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#
class Message < ApplicationRecord
  belongs_to :conversation

  enum :role, { user: 0, assistant: 1, system: 2 }

  validates :role, presence: true
  validates :content, presence: true
end
