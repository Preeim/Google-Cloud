# ==============================================================================
# Bánk's Repository - Adminisztrátori Bázis Vezérlő (Admin::BaseController)
# ==============================================================================
# Minden adminisztrátori vezérlő ebből az osztályból származik.
# Garantálja, hogy kizárólag érvényes, admin szerepkörű felhasználók érhetik el,
# és beállítja a dedikált adminisztrációs felületi sablont (layout: 'admin').
# ==============================================================================

module Admin
  class BaseController < ApplicationController
    before_action :require_admin!
    before_action :check_admin_session_timeout!
    layout "admin"

    private

    ADMIN_SESSION_TIMEOUT = 30.minutes

    def check_admin_session_timeout!
      last_active = session[:admin_last_active_at]

      if last_active.present?
        last_active_time = last_active.is_a?(Time) ? last_active : Time.parse(last_active.to_s)
        if Time.current - last_active_time > ADMIN_SESSION_TIMEOUT
          session.delete(:admin_last_active_at)
          redirect_to login_path, alert: "Az admin munkamenet lejárt (#{ADMIN_SESSION_TIMEOUT / 60} perc inaktivitás). Kérlek, lépj be újra."
          return
        end
      end

      session[:admin_last_active_at] = Time.current
    end
  end
end

