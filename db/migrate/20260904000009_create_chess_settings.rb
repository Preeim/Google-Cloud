# ==============================================================================
# Migráció: Sakk Modul Beállítások (ChessSettings) Tábla Létrehozása
# ==============================================================================

class CreateChessSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :chess_settings do |t|
      t.boolean :allow_guests, default: true, null: false
      t.integer :default_time_control, default: 600, null: false
      t.string  :available_time_controls, default: "0,180,300,600,900,1800", null: false
      t.boolean :allow_takeback, default: true, null: false
      t.boolean :allow_draw_offer, default: true, null: false
      t.integer :auto_abort_minutes, default: 30, null: false
      t.boolean :single_challenge_limit, default: true, null: false

      t.timestamps
    end
  end
end
