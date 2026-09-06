# ==============================================================================
# Bánk's Repository - Sakk Modul Bázis Modell (Chess::ApplicationRecord)
# ==============================================================================
# Minden Sakk modulhoz tartozó ActiveRecord modell ebből származik.
# Automatikusan a 'chess_' prefixet alkalmazza a táblanevekre (pl. chess_games).
# ==============================================================================

module Chess
  class ApplicationRecord < ::ApplicationRecord
    self.abstract_class = true
    self.table_name_prefix = "chess_"
  end
end

