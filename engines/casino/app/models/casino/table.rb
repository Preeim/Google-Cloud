module Casino
  class Table < ApplicationRecord
    has_many :bets, class_name: "Casino::Bet", foreign_key: :casino_table_id, dependent: :destroy

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true
    validates :game_type, inclusion: { in: %w[roulette baccarat blackjack] }
    validates :state, inclusion: { in: %w[idle betting player_turns resolving maintenance] }
    validates :min_bet, numericality: { greater_than: 0 }
    validates :max_bet, numericality: { greater_than: 0 }
    validate :min_bet_cannot_exceed_max_bet

    scope :roulette_tables, -> { where(game_type: "roulette") }
    scope :baccarat_tables, -> { where(game_type: "baccarat") }
    scope :blackjack_tables, -> { where(game_type: "blackjack") }
    scope :active, -> { where.not(state: "maintenance") }

    private

    def min_bet_cannot_exceed_max_bet
      return unless min_bet.present? && max_bet.present?
      if min_bet > max_bet
        errors.add(:min_bet, "nem lehet nagyobb a maximális tétnél (#{max_bet})")
      end
    end

    public

    def to_param
      slug
    end

    def current_state_data
      return {} if state_data.blank?
      JSON.parse(state_data) rescue {}
    end

    def update_state_data!(data)
      update!(state_data: data.to_json)
    end

    def current_bets
      bets.where(round_number: round_number)
    end

    def betting_open?
      state == "betting" && (betting_closes_at.nil? || betting_closes_at > Time.current)
    end

    def turn_decision_open?
      state == "player_turns" && (betting_closes_at.nil? || betting_closes_at > Time.current)
    end

    def seconds_remaining
      return 0 if betting_closes_at.nil? || betting_closes_at <= Time.current
      [((betting_closes_at - Time.current)).round, 0].max
    end
  end
end

