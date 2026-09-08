# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let!(:admin) { User.create!(username: "admin_boss", email: "admin@bankrepo.hu", password: "AdminPassword123!", role: "admin") }
  let!(:regular_user) { User.create!(username: "regular_joe", email: "joe@bankrepo.hu", password: "UserPassword123!", role: "user") }

  def login_as(user)
    post "/login", params: { login: user.username, password: user.username == "admin_boss" ? "AdminPassword123!" : "UserPassword123!" }
  end

  describe "Access Control" do
    it "denies regular users access to bank-admin" do
      login_as(regular_user)
      get "/bank-admin/users"

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end

    it "allows admins access to bank-admin" do
      login_as(admin)
      get "/bank-admin/users"

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /bank-admin/users/:id/unlock" do
    it "unlocks a locked user" do
      regular_user.lock_access!
      expect(regular_user.locked?).to be true

      login_as(admin)
      post "/bank-admin/users/#{regular_user.id}/unlock"

      expect(response).to redirect_to("/bank-admin/users")
      expect(regular_user.reload.locked?).to be false
    end
  end

  describe "Self-protection safeguards" do
    it "prevents an admin from demoting or locking their own account" do
      login_as(admin)
      patch "/bank-admin/users/#{admin.id}", params: { user: { role: "user" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(admin.reload.role).to eq("admin")
    end

    it "prevents an admin from deleting their own account" do
      login_as(admin)
      delete "/bank-admin/users/#{admin.id}"

      expect(response).to redirect_to("/bank-admin/users")
      expect(flash[:alert]).to include("Saját adminisztrátori fiókodat nem törölheted")
      expect(User.find_by(id: admin.id)).to be_present
    end
  end
end
