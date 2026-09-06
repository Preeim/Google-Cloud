module Casino
  class LobbyController < ApplicationController
    def index
      @roulette_tables = Casino::Table.roulette_tables.active
      @baccarat_tables = Casino::Table.baccarat_tables.active
      @blackjack_tables = Casino::Table.blackjack_tables.active

      @profile = current_casino_profile
      @recent_bets = @profile.bets.order(created_at: :desc).limit(5)
      @top_players = Casino::Profile.leaderboard.includes(:user).limit(5)
    end
  end
end

