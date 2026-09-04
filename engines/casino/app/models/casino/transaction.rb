module Casino
  class Transaction < ApplicationRecord
    belongs_to :profile, class_name: "Casino::Profile", foreign_key: :casino_profile_id

    validates :amount, presence: true
    validates :transaction_type, presence: true
    validates :balance_after, presence: true

    scope :recent, -> { order(created_at: :desc) }

    def parsed_metadata
      return {} if metadata.blank?
      JSON.parse(metadata) rescue {}
    end
  end
end

