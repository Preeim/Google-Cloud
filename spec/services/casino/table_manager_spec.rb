# frozen_string_literal: true

require "rails_helper"

RSpec.describe Casino::TableManager do
  let!(:user) { User.create!(username: "gambler", email: "gambler@bankrepo.hu", password: "Password123!") }
  let!(:profile) { Casino::Profile.create!(user: user, chips: 5000) }
  let!(:table) { Casino::Table.create!(slug: "test-roulette", name: "Test Roulette", game_type: "roulette", min_bet: 50, max_bet: 5000) }

  before do
    Rails.cache.clear
  end

  describe "presence management via Rails.cache" do
    it "registers, checks, and unregisters online players using cache" do
      expect(Casino::TableManager.has_online_players?(table.id)).to be false
      expect(Casino::TableManager.online_players_count(table.id)).to eq(0)

      Casino::TableManager.register_presence(table.id, user.id)
      expect(Casino::TableManager.has_online_players?(table.id)).to be true
      expect(Casino::TableManager.online_players_count(table.id)).to eq(1)

      Casino::TableManager.unregister_presence(table.id, user.id)
      expect(Casino::TableManager.has_online_players?(table.id)).to be false
      expect(Casino::TableManager.online_players_count(table.id)).to eq(0)
    end
  end

  describe ".place_bet" do
    it "places a valid bet on roulette and deducts chips" do
      result = Casino::TableManager.place_bet(table, profile, "red", 100)

      expect(result[:success]).to be true
      expect(profile.reload.chips).to eq(4900)
      expect(table.bets.count).to eq(1)
      expect(table.reload.state).to eq("betting")
    end

    it "rejects bets exceeding user balance" do
      result = Casino::TableManager.place_bet(table, profile, "black", 10000)

      expect(result[:success]).to be false
      expect(result[:error_code]).to eq("insufficient_chips")
      expect(profile.reload.chips).to eq(5000)
    end
  end
end
