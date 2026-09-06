module Casino
  class Profile < ApplicationRecord
    belongs_to :user, class_name: "::User"
    has_many :transactions, class_name: "Casino::Transaction", foreign_key: :casino_profile_id, dependent: :destroy
    has_many :bets, class_name: "Casino::Bet", foreign_key: :casino_profile_id, dependent: :destroy

    validates :chips, numericality: { greater_than_or_equal_to: 0 }
    validates :total_rounds_played, numericality: { greater_than_or_equal_to: 0 }
    validates :total_won_rounds, numericality: { greater_than_or_equal_to: 0 }
    validates :user_id, uniqueness: true

    scope :leaderboard, -> { order(chips: :desc, total_won_rounds: :desc) }

    def can_afford?(amount)
      amount.to_i > 0 && chips >= amount.to_i
    end

    def add_chips!(amount, transaction_type:, game_type: "system", metadata: {})
      amount = amount.to_i
      return false if amount <= 0

      with_lock do
        new_balance = chips + amount
        update!(chips: new_balance)
        transactions.create!(
          amount: amount,
          transaction_type: transaction_type,
          game_type: game_type,
          balance_after: new_balance,
          metadata: metadata.to_json
        )
      end
      true
    end

    def deduct_chips!(amount, transaction_type:, game_type: "system", metadata: {})
      amount = amount.to_i
      return false if amount <= 0

      with_lock do
        raise "Fedezethiány" if chips < amount

        new_balance = chips - amount
        update!(chips: new_balance)
        transactions.create!(
          amount: -amount,
          transaction_type: transaction_type,
          game_type: game_type,
          balance_after: new_balance,
          metadata: metadata.to_json
        )
      end
      true
    end

    def set_balance!(new_amount, actor: nil)
      new_amount = new_amount.to_i
      return false if new_amount < 0

      with_lock do
        diff = new_amount - chips
        update!(chips: new_amount)
        transactions.create!(
          amount: diff,
          transaction_type: "admin_adjustment",
          game_type: "system",
          balance_after: new_amount,
          metadata: { actor_id: actor&.id, actor_name: actor&.username }.to_json
        )
      end
      true
    end

    def reset_to_default!(actor: nil)
      set_balance!(10000, actor: actor)
    end
  end
end

