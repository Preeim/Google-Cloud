# ==============================================================================
# Bánk's Repository - Sakk Modul Műszerfal Vezérlő (Chess::DashboardController)
# ==============================================================================
# A sakk alkalmazás kezdőlapja: lobby nézet, új játék indítása, és meglévő
# partik megtekintése.
# ==============================================================================

module Chess
  class DashboardController < ApplicationController
    def index
      # Később ide kerül az aktív partik és játékosok lekérdezése:
      # @active_games = Game.where(state: "in_progress")
    end
  end
end

