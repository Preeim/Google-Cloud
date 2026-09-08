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
    
    # Valós idejű online és aktív közösségi adatok
    online_scope = User.online
    @online_count = online_scope.count
    @online_users = online_scope.order(last_seen_at: :desc).limit(20)
    @total_users_count = User.count
    @recent_active_users = User.where.not(last_seen_at: nil).order(last_seen_at: :desc).limit(12)
  end
end

