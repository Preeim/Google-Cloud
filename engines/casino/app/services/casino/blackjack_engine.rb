require "securerandom"

module Casino
  class BlackjackEngine
    SUITS = %w[♠ ♥ ♦ ♣].freeze
    RANKS = %w[A 2 3 4 5 6 7 8 9 10 J Q K].freeze

    def self.new_shuffled_deck(decks_count = 6)
      deck = []
      decks_count.times do
        SUITS.each do |suit|
          RANKS.each do |rank|
            deck << { suit: suit, rank: rank }
          end
        end
      end
      deck.shuffle
    end

    def self.card_point(rank)
      case rank.to_s
      when "A" then 11
      when "10", "J", "Q", "K" then 10
      else rank.to_i
      end
    end

    # Kiszámítja a kéz értékét figyelembe véve a rugalmas Ász (1 vagy 11) értéket
    def self.hand_value(cards)
      return 0 if cards.blank?

      total = 0
      aces = 0

      cards.each do |c|
        rank = (c["rank"] || c[:rank]).to_s
        val = card_point(rank)
        total += val
        aces += 1 if rank == "A"
      end

      # Ha besokallna (> 21) és van Ász, az Ászok értékét 11 helyett 1-re vesszük le (-10 pont)
      while total > 21 && aces > 0
        total -= 10
        aces -= 1
      end

      total
    end

    def self.blackjack?(cards)
      cards.size == 2 && hand_value(cards) == 21
    end

    def self.busted?(cards)
      hand_value(cards) > 21
    end

    # Az osztó levezeti a saját húzásait: 17 alatt húz, 17-nél vagy felette megáll
    def self.play_dealer_hand(dealer_cards, deck)
      cards = dealer_cards.dup
      while hand_value(cards) < 17
        card = deck.pop || new_shuffled_deck.pop
        cards << card
      end
      cards
    end

    # Értékeli a játékos és az osztó kezét, visszadva az eredményt és a kifizetési szorzót
    def self.evaluate_outcome(player_cards, dealer_cards, bet_amount)
      p_score = hand_value(player_cards)
      d_score = hand_value(dealer_cards)
      p_bj = blackjack?(player_cards)
      d_bj = blackjack?(dealer_cards)

      if p_score > 21
        return { result: "bust", payout: 0, player_score: p_score, dealer_score: d_score }
      end

      if p_bj && d_bj
        return { result: "push", payout: bet_amount, player_score: 21, dealer_score: 21 }
      elsif p_bj
        # Blackjack kifizetés 3:2 (tét + 1.5x profit)
        return { result: "blackjack", payout: bet_amount + (bet_amount * 1.5).floor, player_score: 21, dealer_score: d_score }
      elsif d_bj
        return { result: "loss", payout: 0, player_score: p_score, dealer_score: 21 }
      end

      if d_score > 21
        # Osztó besokallt
        { result: "win", payout: bet_amount * 2, player_score: p_score, dealer_score: d_score }
      elsif p_score > d_score
        # Játékos magasabb pontszámot ért el
        { result: "win", payout: bet_amount * 2, player_score: p_score, dealer_score: d_score }
      elsif p_score < d_score
        # Osztó magasabb pontszámot ért el
        { result: "loss", payout: 0, player_score: p_score, dealer_score: d_score }
      else
        # Döntetlen (Push) - a tét visszajár
        { result: "push", payout: bet_amount, player_score: p_score, dealer_score: d_score }
      end
    end
  end
end

