# frozen_string_literal: true

require "rails_helper"

RSpec.describe Casino::Profile, type: :model do
  let(:user) { User.create!(username: "casino_player", email: "player@bankrepo.hu", password: "password123") }
  let(:profile) { Casino::Profile.create!(user: user, chips: 5000) }

  describe "#add_chips!" do
    it "increases chip balance and creates a transaction record" do
      expect {
        profile.add_chips!(1000, transaction_type: "payout", game_type: "roulette")
      }.to change { profile.reload.chips }.from(5000).to(6000)
       .and change { profile.transactions.count }.by(1)

      last_tx = profile.transactions.last
      expect(last_tx.amount).to eq(1000)
      expect(last_tx.balance_after).to eq(6000)
      expect(last_tx.transaction_type).to eq("payout")
    end
  end

  describe "#deduct_chips!" do
    it "decreases chip balance when sufficient funds exist" do
      expect {
        profile.deduct_chips!(2000, transaction_type: "bet", game_type: "blackjack")
      }.to change { profile.reload.chips }.from(5000).to(3000)
       .and change { profile.transactions.count }.by(1)

      last_tx = profile.transactions.last
      expect(last_tx.amount).to eq(-2000)
      expect(last_tx.balance_after).to eq(3000)
    end

    it "raises an exception and preserves balance when insufficient funds" do
      expect {
        profile.deduct_chips!(10000, transaction_type: "bet", game_type: "roulette")
      }.to raise_error(RuntimeError, "Fedezethiány")

      expect(profile.reload.chips).to eq(5000)
    end
  end
end
