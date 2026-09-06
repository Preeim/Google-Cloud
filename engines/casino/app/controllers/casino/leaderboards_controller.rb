module Casino
  class LeaderboardsController < ApplicationController
    def index
      @profiles = Casino::Profile.leaderboard.includes(:user).limit(50)
      @my_profile = current_casino_profile
      @my_rank = Casino::Profile.where(
        "chips > :chips OR (chips = :chips AND total_won_rounds > :won)",
        chips: @my_profile.chips, won: @my_profile.total_won_rounds
      ).count + 1
    end
  end
end

