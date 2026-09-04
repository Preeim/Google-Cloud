# ==============================================================================
# Migráció: Aktív Munkamenetek (ActiveSessions) Tábla Létrehozása
# ==============================================================================
# Lehetővé teszi az egyidejű bejelentkezések (asztali gép, mobil) követését,
# a munkamenet-rablás megelőzését és az adminisztrátori távoli kiléptetést.
# A session tokenek kizárólag SHA-256 lenyomatként (digest) kerülnek tárolásra.
# ==============================================================================

class CreateActiveSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :active_sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string     :session_token_digest, null: false
      t.string     :ip_address
      t.string     :user_agent
      t.datetime   :last_activity_at, null: false
      t.datetime   :expires_at, null: false

      t.timestamps
    end

    add_index :active_sessions, :session_token_digest, unique: true
    add_index :active_sessions, :expires_at
    add_index :active_sessions, [:user_id, :last_activity_at]
  end
end

