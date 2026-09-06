# ==============================================================================
# Bánk's Repository - Kaszinó Modul (Casino Engine Belépési Pont)
# ==============================================================================
# Ez a fájl tölti be az izolált Kaszinó modult (Rails Engine).
# Definiálja a modul névterét és az adatbázis táblanév prefixet (casino_).
# ==============================================================================

require_relative "casino/engine"

module Casino
  def self.table_name_prefix
    "casino_"
  end
end

