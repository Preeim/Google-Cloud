# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Chess::Matches", type: :request do
  let!(:player1) { User.create!(username: "kasparov", email: "kasparov@bankrepo.hu", password: "Password123!") }
  let!(:player2) { User.create!(username: "karpov", email: "karpov@bankrepo.hu", password: "Password123!") }

  before do
    Chess::Setting.current
  end

  def login_as(user)
    post "/login", params: { login: user.username, password: "Password123!" }
  end

  describe "POST /chess/matches" do
    it "creates a new pending match" do
      login_as(player1)

      expect {
        post "/chess/matches", params: { time_control: 300, side: "white" }
      }.to change(Chess::Match, :count).by(1)

      match = Chess::Match.last
      expect(match.white_user_id).to eq(player1.id)
      expect(match.status).to eq("pending")
      expect(response).to redirect_to("/chess/matches/#{match.uuid}")
    end
  end

  describe "POST /chess/matches/:id/join" do
    it "joins a pending match and activates it" do
      match = Chess::Match.create!(white_user_id: player1.id, status: "pending", time_control: 600)

      login_as(player2)
      post "/chess/matches/#{match.uuid}/join"

      expect(response).to redirect_to("/chess/matches/#{match.uuid}")
      expect(match.reload.status).to eq("active")
      expect(match.black_user_id).to eq(player2.id)
    end
  end

  describe "GET /chess/matches/:id" do
    it "does NOT automatically join or mutate a pending match on GET show" do
      match = Chess::Match.create!(white_user_id: player1.id, status: "pending", time_control: 600)

      login_as(player2)
      get "/chess/matches/#{match.uuid}"

      expect(response).to have_http_status(:ok)
      expect(match.reload.status).to eq("pending")
      expect(match.black_user_id).to be_nil
    end
  end

  describe "POST /chess/matches/:id/cancel" do
    it "allows creator to cancel pending match" do
      match = Chess::Match.create!(white_user_id: player1.id, status: "pending")

      login_as(player1)
      post "/chess/matches/#{match.uuid}/cancel"

      expect(response).to redirect_to("/chess/matches")
      expect(Chess::Match.find_by(id: match.id)).to be_nil
    end
  end
end
