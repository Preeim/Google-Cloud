module Chess
  module Admin
    class DashboardController < BaseController
      def index
        @total_matches = Match.count
        @pending_matches_count = Match.where(status: 'pending').count
        @active_matches_count = Match.where(status: 'active').count
        @completed_matches_count = Match.where(status: 'completed').count
        @aborted_matches_count = Match.where(status: 'aborted').count

        @white_wins = Match.where(winner: 'white').count
        @black_wins = Match.where(winner: 'black').count
        @draws = Match.where(winner: 'draw').count

        @recent_matches = Match.order(created_at: :desc).limit(8)
        @settings = Chess::Setting.current
      end
    end
  end
end
