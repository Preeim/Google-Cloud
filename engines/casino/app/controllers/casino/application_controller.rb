module Casino
  class ApplicationController < ::ApplicationController
    # Modul hozzáférési szűrő futtatása a platform AppDefinition konfigurációjához
    before_action -> { check_app_access!("casino") }
    before_action :authenticate_user!
    before_action :ensure_casino_profile

    helper_method :current_casino_profile

    layout "casino/application"

    private

    def ensure_casino_profile
      return unless logged_in?

      @current_casino_profile = Casino::Profile.find_or_create_by!(user_id: current_user.id) do |p|
        p.chips = 10000
        p.total_rounds_played = 0
        p.total_won_rounds = 0
      end
    end

    def current_casino_profile
      @current_casino_profile
    end
  end
end

