# ==============================================================================
# Bánk's Repository - Rajzvászon Modul (Canvas Engine Belépési Pont)
# ==============================================================================
# Ez a fájl tölti be az izolált Rajzvászon modult (Rails Engine).
# Definiálja a modul globális névterét és az adatbázis táblanév prefixet (canvas_).
# ==============================================================================

require_relative "canvas/engine"

module Canvas
  def self.table_name_prefix
    "canvas_"
  end
end
