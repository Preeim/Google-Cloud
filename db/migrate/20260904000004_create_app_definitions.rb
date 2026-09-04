# ==============================================================================
# Migráció: Alkalmazás Definíciók (AppDefinitions) Tábla Létrehozása
# ==============================================================================
# A platformhoz kapcsolt beépülő modulok (pl. Sakk, Jegyzetek, Statisztika)
# központi regisztere. Tartalmazza a csatolási pontot, a modul elérhetőségét
# (aktív, karbantartás alatt, tiltva), és az alapértelmezett hozzáférési jogot.
# ==============================================================================

class CreateAppDefinitions < ActiveRecord::Migration[7.1]
  def change
    create_table :app_definitions do |t|
      t.string  :slug, null: false                   # pl. "chess"
      t.string  :name, null: false                   # pl. "Bánk Chess Engine"
      t.text    :description                         # Modul rövid leírása
      t.string  :mount_path, null: false             # pl. "/chess"
      t.string  :state, default: "active", null: false # active, maintenance, disabled, admin_only
      t.string  :icon_identifier                     # pl. "chess-knight"
      t.boolean :is_default_accessible, default: true, null: false

      t.timestamps
    end

    add_index :app_definitions, :slug, unique: true
    add_index :app_definitions, :state
  end
end

