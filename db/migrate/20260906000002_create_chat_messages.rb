# frozen_string_literal: true

# ==============================================================================
# Migráció: Globális Chat Üzenetek Tábla (chat_messages)
# ==============================================================================
# Tárolja a platform valós idejű globális csevegésében közzétett üzeneteket.
# Támogatja a felhasználói asszociációt, a soft-delete moderációt
# és az időbélyeg szerinti gyors lekérdezést.
# ==============================================================================

class CreateChatMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :chat_messages do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.text       :content, null: false
      t.datetime   :deleted_at, index: true

      t.timestamps
    end

    add_index :chat_messages, [:created_at, :deleted_at]
  end
end