# ==============================================================================
# Bánk's Repository - Biztonság & Munkamenetek Widget (AccountSecurityWidget)
# ==============================================================================
# Privát kártya (Csak tulajdonosnak és Adminnak):
# Megjeleníti a jelenleg aktív bejelentkezéseket (ActiveSession tábla), IP címeket,
# böngészőt, a jelszó legutóbbi módosításának idejét, valamint a profil gyors-szerkesztési opciókat.
# ==============================================================================

module ProfileWidgets
  class AccountSecurityWidget < BaseWidget
    def initialize
      super(
        id: :account_security,
        title: "Fiókbiztonság & Aktív Munkamenetek",
        icon: "🛡️",
        partial: "profiles/widgets/account_security",
        priority: 40,
        column_span: 2,
        owner_only: true # KIZÁRÓLAG TULAJDONOSNAK ÉS ADMINNAK
      )
    end

    def load_data(profile_user, viewer_user)
      active_sessions = profile_user.active_sessions.active.order(last_activity_at: :desc).limit(6)
      
      {
        active_sessions: active_sessions,
        password_changed_at: profile_user.password_changed_at,
        failed_logins_count: profile_user.failed_logins_count,
        locked_until: profile_user.locked_until,
        last_login_at: profile_user.last_login_at,
        is_owner: viewer_user.present? && viewer_user.id == profile_user.id
      }
    end
  end
end

