# ==============================================================================
# Bánk's Repository - Központi Műszerfal Vezérlő (DashboardController)
# ==============================================================================
# A platform kezdőlapja bejelentkezett felhasználók számára.
# Megjeleníti az elérhető beépülő modulokat (pl. Sakk), a legutóbbi partikat,
# a rendszerstátuszt és az új funkciók beharangozóját.
# ==============================================================================

class DashboardController < ApplicationController
  def index
    @available_apps = AppDefinition.where(state: ["active", "maintenance"])
  end
end

