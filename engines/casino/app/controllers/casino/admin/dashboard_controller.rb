module Casino
  module Admin
    class DashboardController < BaseController
      def index
        @total_chips = Casino::Profile.sum(:chips)
        @total_profiles = Casino::Profile.count
        @total_bets = Casino::Bet.count
        @total_rounds = Casino::Table.sum(:round_number)
        @tables = Casino::Table.all.order(:game_type, :name)
        @recent_transactions = Casino::Transaction.includes(profile: :user).recent.limit(10)
      end
    end
  end
end

