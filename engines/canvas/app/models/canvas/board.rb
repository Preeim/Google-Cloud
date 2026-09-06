# ==============================================================================
# Bánk's Repository - Rajzvászon Modell (Canvas::Board)
# ==============================================================================

module Canvas
  class Board < ApplicationRecord
    self.table_name = "canvas_boards"

    has_many :strokes, class_name: "Canvas::Stroke", foreign_key: :board_id, dependent: :destroy

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true

    # Az alapértelmezett közösségi tábla lekérése vagy inicializálása
    def self.default_board
      find_or_create_by!(slug: "main") do |b|
        b.name = "Közösségi Rajzvászon"
        b.width = 1600
        b.height = 900
        b.is_frozen = false
        b.strokes_count = 0
      end
    end

    # A teljes tábla azonnali ürítése
    def clear_canvas!
      transaction do
        strokes.delete_all
        update!(snapshot_data: nil, strokes_count: 0)
      end
    end

    # Pillanatfelvétel (PNG Data URL) mentése és a korábbi stroke-ok opcionális tömörítése
    def save_snapshot!(data_url)
      return if data_url.blank?

      transaction do
        update!(snapshot_data: data_url)
        # Ha a stroke-ok száma nagy, a snapshot megtartása mellett a már rétegbe épült régebbi stroke-ok tisztíthatók
        if strokes.count > 100
          cutoff_id = strokes.order(id: :desc).offset(30).pick(:id)
          strokes.where("id < ?", cutoff_id).delete_all if cutoff_id
          update_column(:strokes_count, strokes.count)
        end
      end
    end

    # Zárolási állapot váltása
    def toggle_freeze!
      update!(is_frozen: !is_frozen)
    end
  end
end

