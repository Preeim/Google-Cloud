# ==============================================================================
# Migráció: Profil Adatok és Jelenlét (Presence) a Felhasználókhoz
# ==============================================================================
# Bővíti a users táblát az online aktivitás követéséhez (last_seen_at),
# valamint a moduláris felhasználói profil testreszabási adataihoz
# (bio, display_name, avatar_color, custom_status).
# ==============================================================================

class AddProfileFieldsAndPresenceToUsers < ActiveRecord::Migration[7.1]
  def change
    change_table :users, bulk: true do |t|
      # Valós idejű jelenlét és online státusz
      t.datetime :last_seen_at

      # Személyreszabott profiladatok
      t.string   :display_name, limit: 50
      t.text     :bio
      t.string   :avatar_color, limit: 20, default: "#38bdf8", null: false
      t.string   :custom_status, limit: 120
    end

    add_index :users, :last_seen_at
  end
end

