# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:user) { User.create!(username: "session_user", email: "session@bankrepo.hu", password: "SecurePassword123!") }

  describe "POST /login" do
    it "logs in successfully with correct credentials and creates ActiveSession" do
      post "/login", params: { login: "session_user", password: "SecurePassword123!" }

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to be_present
      expect(session[:user_id]).to eq(user.id)
      expect(session[:session_token]).to be_present
      expect(ActiveSession.count).to eq(1)
    end

    it "fails login with incorrect password and increments failed_logins_count" do
      post "/login", params: { login: "session_user", password: "WrongPassword" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:alert]).to be_present
      expect(session[:user_id]).to be_nil
      expect(user.reload.failed_logins_count).to eq(1)
    end

    it "blocks login when account is locked" do
      user.lock_access!

      post "/login", params: { login: "session_user", password: "SecurePassword123!" }

      expect(response).to have_http_status(:locked)
      expect(flash[:alert]).to include("zárolva")
      expect(session[:user_id]).to be_nil
    end

    it "allows strong passwords containing special characters" do
      strong_user = User.create!(username: "strong_user", email: "strong@bankrepo.hu", password: "P@ssw0rd--123;/*safe*/")

      post "/login", params: { login: "strong_user", password: "P@ssw0rd--123;/*safe*/" }

      expect(response).to redirect_to(root_path)
      expect(session[:user_id]).to eq(strong_user.id)
    end
  end

  describe "DELETE /logout" do
    it "logs out user, destroys ActiveSession and clears session" do
      post "/login", params: { login: "session_user", password: "SecurePassword123!" }
      token = session[:session_token]
      expect(ActiveSession.find_by_raw_token(token)).to be_present

      delete "/logout"

      expect(response).to redirect_to(root_path)
      expect(session[:user_id]).to be_nil
      expect(ActiveSession.find_by_raw_token(token)).to be_nil
    end
  end

  describe "GET /logout" do
    it "returns 404/RoutingError to prevent CSRF logout via GET" do
      expect {
        get "/logout"
      }.to raise_error(ActionController::RoutingError)
    end
  end
end
