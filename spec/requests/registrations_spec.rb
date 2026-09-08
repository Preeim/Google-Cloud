# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "POST /register" do
    it "creates a new user and logs them in" do
      expect {
        post "/register", params: {
          user: {
            username: "newbie",
            email: "newbie@bankrepo.hu",
            password: "MySecurePassword123!",
            password_confirmation: "MySecurePassword123!"
          }
        }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(root_path)
      created = User.find_by(username: "newbie")
      expect(created).to be_present
      expect(created.role).to eq("user")
      expect(session[:user_id]).to eq(created.id)
    end

    it "blocks bot registration when honeypot field is filled" do
      expect {
        post "/register", params: {
          hp_security_verification: "spam_bot_data",
          user: {
            username: "spambot",
            email: "spambot@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          }
        }
      }.not_to change(User, :count)

      expect(response).to redirect_to(register_path)
      expect(flash[:alert]).to include("Biztonsági ellenőrzés")
    end

    it "does not allow mass assignment of admin role" do
      post "/register", params: {
        user: {
          username: "hacker",
          email: "hacker@bankrepo.hu",
          password: "Password123!",
          password_confirmation: "Password123!",
          role: "admin"
        }
      }

      created = User.find_by(username: "hacker")
      expect(created.role).to eq("user")
    end
  end
end
