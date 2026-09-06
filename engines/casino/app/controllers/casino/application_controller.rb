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

      created_new = false
      begin
        @current_casino_profile = Casino::Profile.find_or_create_by!(user_id: current_user.id) do |p|
          p.chips = 10000
          p.total_rounds_played = 0
          p.total_won_rounds = 0
          created_new = true
        end
      rescue ActiveRecord::RecordNotUnique
        @current_casino_profile = Casino::Profile.find_by(user_id: current_user.id)
      end

      if created_new && @current_casino_profile.present? && @current_casino_profile.transactions.empty?
        @current_casino_profile.transactions.create!(
          amount: 10000,
          transaction_type: "welcome_bonus",
          game_type: "system",
          balance_after: 10000,
          metadata: { note: "Kezdő kredit jóváírás" }.to_json
        )
      end
    end

    def current_casino_profile
      @current_casino_profile
    end
  end
end

