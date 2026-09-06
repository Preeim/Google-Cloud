# ==============================================================================
# Bánk's Repository - Rajzvászon Vonalmozdulat Modell (Canvas::Stroke)
# ==============================================================================

module Canvas
  class Stroke < ApplicationRecord
    self.table_name = "canvas_strokes"

    belongs_to :board, class_name: "Canvas::Board", foreign_key: :board_id, counter_cache: :strokes_count
    belongs_to :user, class_name: "::User", foreign_key: :user_id, optional: true

    validates :tool, inclusion: { in: %w[brush eraser] }
    validates :color, presence: true
    validates :width, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
    validates :points_data, presence: true

    # Pontok JSON visszafejtése
    def parsed_points
      JSON.parse(points_data) rescue []
    end

    # Pontok beállítása tömbből
    def parsed_points=(pts)
      self.points_data = pts.is_a?(String) ? pts : pts.to_json
    end

    # WebSocket átvitelhez formázott adatcsomag
    def as_payload
      {
        id: id,
        user_id: user_id,
        username: user&.username || "Vendég",
        tool: tool,
        color: color,
        width: width,
        points: parsed_points,
        created_at: created_at&.iso8601
      }
    end
  end
end
