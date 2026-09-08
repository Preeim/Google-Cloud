# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Session Security & Recovery", type: :request do
  let!(:active_user) { User.create!(username: "active_user", email: "active@bankrepo.hu", password: "SecurePassword123!", status: "active") }
  let!(:suspended_user) { User.create!(username: "suspended_user", email: "suspended@bankrepo.hu", password: "SecurePassword123!", status: "suspended") }
  let!(:locked_user) { User.create!(username: "locked_user", email: "locked@bankrepo.hu", password: "SecurePassword123!", status: "active") }

  before do
    locked_user.lock_access!
  end

  describe "Authentication status checks" do
    it "authenticates active users normally" do
      post "/login", params: { login: "active_user", password: "SecurePassword123!" }
      expect(response).to redirect_to(root_path)
      expect(session[:user_id]).to eq(active_user.id)
    end

    it "rejects login for suspended users" do
      post "/login", params: { login: "suspended_user", password: "SecurePassword123!" }
      expect(response).to have_http_status(:forbidden)
      expect(session[:user_id]).to be_nil
    end

    it "rejects login for locked users" do
      post "/login", params: { login: "locked_user", password: "SecurePassword123!" }
      expect(response).to have_http_status(:locked)
      expect(session[:user_id]).to be_nil
    end
  end

  describe "Registration validation" do
    it "allows registration with standard alphanumeric username and strict email" do
      post "/register", params: {
        user: {
          username: "new_player99",
          email: "player99@bankrepo.hu",
          password: "MySecurePassword123!",
          password_confirmation: "MySecurePassword123!"
        }
      }

      expect(response).to redirect_to(root_path)
      created = User.find_by(username: "new_player99")
      expect(created).to be_present
      expect(created.status).to eq("active")
      expect(created.role).to eq("user")
    end
  end

  describe "Casino::Scheduler Leader Locking" do
    it "acquires leader lock and allows single-leader execution" do
      Rails.cache.clear
      expect(Casino::Scheduler.acquire_leader_lock!).to be true
      expect(Casino::Scheduler.running?).to be_falsey
      Casino::Scheduler.release_leader_lock!
    end
  end
end

