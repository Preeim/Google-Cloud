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
end

