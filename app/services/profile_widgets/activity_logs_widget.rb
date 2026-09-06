# ==============================================================================
# Bánk's Repository - Aktivitási & Rendszernapló Widget (ActivityLogsWidget)
# ==============================================================================
# Privát kártya (Csak tulajdonosnak és Adminnak):
# Az AuditLog tábla alapján megjeleníti a fiókkal kapcsolatos biztonsági és
# aktivitási eseményeket (pl. belépések, módosítások).
# ==============================================================================

module ProfileWidgets
  class ActivityLogsWidget < BaseWidget
    def initialize
      super(
        id: :activity_logs,
        title: "Aktivitási & Biztonsági Napló",
        icon: "📜",
        partial: "profiles/widgets/activity_logs",
        priority: 50,
        column_span: 2,
        owner_only: true # KIZÁRÓLAG TULAJDONOSNAK ÉS ADMINNAK
      )
    end

    def load_data(profile_user, viewer_user)
      logs = if defined?(AuditLog)
               AuditLog.where("actor_user_id = :uid OR target_user_id = :uid", uid: profile_user.id)
                       .order(created_at: :desc)
                       .limit(8)
             else
               []
             end

      {
        logs: logs
      }
    end
  end
end

