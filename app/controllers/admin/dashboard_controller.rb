# ==============================================================================
# Bánk's Repository - Admin Műszerfal Vezérlő (Admin::DashboardController)
# ==============================================================================
# Összegyűjti és megjeleníti a platform legfontosabb statisztikáit:
# felhasználók száma, aktív munkamenetek, zárolt fiókok és az audit napló.
# ==============================================================================

module Admin
  class DashboardController < BaseController
    def index
      @total_users_count    = User.count
      @active_users_count   = User.where(status: "active").count
      @locked_users_count   = User.where("locked_until > ?", Time.current).count
      @active_sessions_count = ActiveSession.where("expires_at > ?", Time.current).count
      @apps                 = AppDefinition.all
      @recent_audit_logs    = AuditLog.order(created_at: :desc).limit(8)
    end
  end
end

