module Casino
  class Bet < ApplicationRecord
    belongs_to :table, class_name: "Casino::Table", foreign_key: :casino_table_id
    belongs_to :profile, class_name: "Casino::Profile", foreign_key: :casino_profile_id

    alias_attribute :profile_id, :casino_profile_id
    alias_attribute :table_id, :casino_table_id

    validates :amount, numericality: { greater_than: 0 }
    validates :bet_type, presence: true
    validates :round_number, numericality: { greater_than: 0 }
    validates :status, inclusion: { in: %w[pending won lost push canceled] }

    scope :for_round, ->(round) { where(round_number: round) }
    scope :pending, -> { where(status: "pending") }
  end
end

