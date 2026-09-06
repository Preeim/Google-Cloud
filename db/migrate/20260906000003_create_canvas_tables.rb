# ==============================================================================
# Bánk's Repository - Rajzvászon Táblák Létrehozása és Modul Regisztráció
# ==============================================================================

class CreateCanvasTables < ActiveRecord::Migration[7.1]
  def up
    # 1. Rajztáblák (Canvas Boards) tábla
    create_table :canvas_boards do |t|
      t.string  :name, null: false, default: "Közösségi Rajzvászon"
      t.string  :slug, null: false, default: "main", index: { unique: true }
      t.boolean :is_frozen, null: false, default: false
      t.integer :width, null: false, default: 1600
      t.integer :height, null: false, default: 900
      t.text    :snapshot_data, size: :long # PNG Data URL az állapot gyors betöltéséhez
      t.integer :strokes_count, null: false, default: 0

      t.timestamps
    end

    # 2. Vonalmozdulatok (Canvas Strokes) tábla
    create_table :canvas_strokes do |t|
      t.references :board, null: false, foreign_key: { to_table: :canvas_boards, on_delete: :cascade }, index: true
      t.references :user, null: true, foreign_key: { to_table: :users, on_delete: :nullify }, index: true
      t.string     :tool, null: false, default: "brush" # "brush", "eraser"
      t.string     :color, null: false, default: "#38bdf8"
      t.integer    :width, null: false, default: 4
      t.text       :points_data, size: :medium, null: false # JSON tömb [[x,y], [x,y], ...]

      t.timestamps
    end

    # 3. AppDefinition regisztráció
    app = AppDefinition.find_or_initialize_by(slug: "canvas")
    app.name = "Közösségi Rajzvászon"
    app.description = "Valós idejű több felhasználós rajzvászon WebSocket szinkronizációval, simított görbékkel és képexporttal."
    app.mount_path = "/canvas"
    app.state = "active"
    app.icon_identifier = "canvas"
    app.is_default_accessible = true
    app.requires_login = false # Vendégek olvashatják (néző mód), belépett tagok rajzolhatnak
    app.save!

    # 4. Kezdő alapértelmezett rajztábla
    execute <<~SQL
      INSERT INTO canvas_boards (name, slug, is_frozen, width, height, strokes_count, created_at, updated_at)
      VALUES ('Közösségi Rajzvászon', 'main', FALSE, 1600, 900, 0, NOW(), NOW())
      ON DUPLICATE KEY UPDATE updated_at = NOW();
    SQL
  end

  def down
    drop_table :canvas_strokes if table_exists?(:canvas_strokes)
    drop_table :canvas_boards if table_exists?(:canvas_boards)
    AppDefinition.find_by(slug: "canvas")&.destroy
  end
end
