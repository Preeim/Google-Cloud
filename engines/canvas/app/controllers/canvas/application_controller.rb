# ==============================================================================
# Bánk's Repository - Rajzvászon Bázis Vezérlő (Canvas::ApplicationController)
# ==============================================================================

module Canvas
  class ApplicationController < ::ApplicationController
    # Modul hozzáférési szűrő
    before_action -> { check_app_access!("canvas") }

    # Vendég azonosító kiosztása, ha nincs belépve felhasználó
    before_action :set_guest_id

    layout "canvas/application"

    helper_method :can_draw?, :read_only?

    def can_draw?(board = nil)
      return false unless logged_in? && current_user.active? && !current_user.locked?
      return true if current_user.admin?

      # Ha a tábla zárolva van, a normál felhasználók nem rajzolhatnak
      if board&.is_frozen?
        return false
      end

      true
    end

    def read_only?(board = nil)
      !can_draw?(board)
    end

    private

    def set_guest_id
      return if logged_in?
      session[:guest_id] ||= SecureRandom.hex(8)
    end
  end
end

