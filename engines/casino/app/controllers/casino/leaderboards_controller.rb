module Casino
  class LeaderboardsController < ApplicationController
    def index
      @profiles = Casino::Profile.leaderboard.includes(:user).limit(50)
      @my_profile = current_casino_profile
      @my_rank = Casino::Profile.where("chips > ?", @my_profile.chips).count + 1
    end
  end
end

