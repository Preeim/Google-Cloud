# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations & normalizations" do
    it "requires a valid username" do
      user = User.new(username: "ab", email: "test@bankrepo.hu", password: "password123")
      expect(user).not_to be_valid
      expect(user.errors[:username]).to be_present
    end

    it "strips and downcases email" do
      user = User.new(username: "tester", email: "  TEST@BankRepo.HU  ", password: "password123")
      user.valid?
      expect(user.email).to eq("test@bankrepo.hu")
    end
  end

  describe "User::Lockable concern" do
    let(:user) { User.create!(username: "lockable_user", email: "lock@bankrepo.hu", password: "password123") }

    it "locks account after 5 failed login attempts" do
      expect(user.locked?).to be false

      4.times { user.record_failed_login! }
      expect(user.locked?).to be false
      expect(user.failed_logins_count).to eq(4)

      user.record_failed_login!
      expect(user.reload.locked?).to be true
      expect(user.failed_logins_count).to eq(5)
      expect(user.locked_until).to be > Time.current
    end

    it "unlocks account and clears counters on unlock_access!" do
      user.lock_access!
      expect(user.locked?).to be true

      user.unlock_access!
      expect(user.reload.locked?).to be false
      expect(user.failed_logins_count).to eq(0)
      expect(user.locked_until).to be_nil
    end
  end

  describe "User::Presentable concern" do
    let(:user) { User.new(username: "bank_user", display_name: "Bánk Nagy") }

    it "returns display name as effective_name when present" do
      expect(user.effective_name).to eq("Bánk Nagy")
    end

    it "calculates avatar initials correctly" do
      expect(user.avatar_initials).to eq("BN")
    end
  end

  describe "User::Authorizable concern" do
    let(:admin_user) { User.create!(username: "admin_user", email: "admin@bankrepo.hu", password: "password123", role: "admin") }
    let(:normal_user) { User.create!(username: "normal_user", email: "normal@bankrepo.hu", password: "password123", role: "user") }
    let!(:app_def) { AppDefinition.create!(slug: "chess", name: "Sakk", mount_path: "/chess", state: "active", is_default_accessible: true) }

    it "allows admin to access any app" do
      expect(admin_user.can_access_app?("chess")).to be true
    end

    it "allows active normal user to access default accessible app" do
      expect(normal_user.can_access_app?("chess")).to be true
    end

    it "denies locked user from accessing apps" do
      normal_user.lock_access!
      expect(normal_user.can_access_app?("chess")).to be false
    end
  end
end

