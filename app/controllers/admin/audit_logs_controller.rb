# ==============================================================================
# Bánk's Repository - Admin Audit Napló Vezérlő (Admin::AuditLogsController)
# ==============================================================================
# Megjeleníti a rendszer biztonsági eseménynaplóját időrendi sorrendben.
# ==============================================================================

module Admin
  class AuditLogsController < BaseController
    def index
      @audit_logs = AuditLog.includes(:actor, :target_user).order(created_at: :desc).limit(100)
    end
  end
end

