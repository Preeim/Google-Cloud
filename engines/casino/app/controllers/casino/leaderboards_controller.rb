module Casino
  class LeaderboardsController < ApplicationController
    def index
      @profiles = Casino::Profile.leaderboard.includes(:user).limit(50)
      @my_profile = current_casino_profile
      @my_rank = Casino::Profile.where(
        "chips > :chips OR (chips = :chips AND total_won_rounds > :won)",
        chips: (@my_profile&.chips || 0), won: (@my_profile&.total_won_rounds || 0)
      ).count + 1

      respond_to do |format|
        format.html
        format.json do
          render json: {
            my_chips: @my_profile&.chips || 0,
            my_rank: @my_rank,
            leaderboard: @profiles.map { |p| { username: p.user.username, chips: p.chips, won: p.total_won_rounds } }
          }
        end
      end
    end
  end
end

