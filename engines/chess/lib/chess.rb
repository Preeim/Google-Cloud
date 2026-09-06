# ==============================================================================
# Bánk's Repository - Sakk Modul (Chess Engine Belépési Pont)
# ==============================================================================
# Ez a fájl tölti be az izolált Sakk modult (Rails Engine).
# Definiálja a modul globális névterét és az adatbázis táblanév prefixet (chess_).
# ==============================================================================

require_relative "chess/engine"

module Chess
  # Minden Sakk modulhoz tartozó adatbázis tábla ezzel a prefixszel kezdődik
  def self.table_name_prefix
    "chess_"
  end
end

