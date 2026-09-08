# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chess::Match, type: :model do
  let(:white_user) { User.create!(username: "white_grandmaster", email: "white@bankrepo.hu", password: "password123") }
  let(:black_user) { User.create!(username: "black_grandmaster", email: "black@bankrepo.hu", password: "password123") }

  describe "associations & helpers" do
    it "associates white_player and black_player correctly" do
      match = Chess::Match.create!(
        white_player: white_user,
        black_player: black_user,
        status: "active"
      )

      expect(match.white_player).to eq(white_user)
      expect(match.black_player).to eq(black_user)
      expect(match.white_player_name).to eq("white_grandmaster")
      expect(match.black_player_name).to eq("black_grandmaster")
    end

    it "falls back to guest label when player is guest" do
      match = Chess::Match.create!(
        white_guest_id: "gst_891234",
        status: "pending"
      )

      expect(match.white_player_name).to eq("Vendég #gst_")
    end
  end

  describe "#check_timeout!" do
    it "marks match as completed with timeout when time expires" do
      match = Chess::Match.create!(
        white_player: white_user,
        black_player: black_user,
        status: "active",
        time_control: 300,
        white_time_left: 1000, # 1 second left
        black_time_left: 300000,
        last_move_at: 5.seconds.ago
      )

      result = match.check_timeout!
      expect(result).to be true
      expect(match.reload.status).to eq("completed")
      expect(match.termination_reason).to eq("timeout")
      expect(match.winner).to eq("black")
    end
  end

  describe "#apply_move!" do
    it "applies a valid move and updates FEN and current turn" do
      match = Chess::Match.create!(
        white_player: white_user,
        black_player: black_user,
        status: "active"
      )

      success = match.apply_move!(from: "e2", to: "e4")
      expect(success).to be true
      expect(match.reload.current_turn).to eq("black")
      expect(match.fen).to include("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3")
    end

    it "rejects illegal moves without altering game state" do
      match = Chess::Match.create!(
        white_player: white_user,
        black_player: black_user,
        status: "active"
      )

      initial_fen = match.fen
      success = match.apply_move!(from: "e2", to: "e5") # illegal jump for pawn
      expect(success).to be false
      expect(match.reload.fen).to eq(initial_fen)
      expect(match.current_turn).to eq("white")
    end
  end
end

