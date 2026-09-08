require "securerandom"

module Casino
  class BaccaratEngine
    SUITS = %w[♠ ♥ ♦ ♣].freeze
    RANKS = %w[A 2 3 4 5 6 7 8 9 10 J Q K].freeze

    def self.create_shoe(deck_count = 6)
      shoe = []
      deck_count.times do
        SUITS.each do |suit|
          RANKS.each do |rank|
            shoe << { suit: suit, rank: rank, value: card_value(rank) }
          end
        end
      end
      secure_shuffle(shoe)
    end

    def self.secure_shuffle(array)
      shuffled = array.dup
      (shuffled.size - 1).downto(1) do |i|
        j = SecureRandom.random_number(i + 1)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
      end
      shuffled
    end

    def self.card_value(rank)
      case rank
      when "A" then 1
      when "10", "J", "Q", "K" then 0
      else rank.to_i
      end
    end

    def self.hand_value(cards)
      sum = cards.sum { |c| c[:value] || card_value(c["rank"] || c[:rank]) }
      sum % 10
    end

    # Levezeti a teljes Punto Banco Baccarat kört a hivatalos nemzetközi szabályok szerint
    def self.play_round
      deck = create_shoe(6) # 6 paklis standard cipő a körhöz

      player_cards = [deck.pop, deck.pop]
      banker_cards = [deck.pop, deck.pop]

      player_total = hand_value(player_cards)
      banker_total = hand_value(banker_cards)

      # 1. Natural vizsgálat (8 vagy 9 az első 2 lapból)
      natural = player_total >= 8 || banker_total >= 8

      unless natural
        player_drew = false
        p3_val = nil

        # 2. Player 3. lap szabály
        if player_total <= 5
          p3 = deck.pop
          player_cards << p3
          p3_val = p3[:value] || card_value(p3["rank"] || p3[:rank])
          player_total = hand_value(player_cards)
          player_drew = true
        end

        # 3. Banker 3. lap szabály
        if !player_drew
          # Ha a játékos nem húzott (6 vagy 7-en állt)
          if banker_total <= 5
            banker_cards << deck.pop
            banker_total = hand_value(banker_cards)
          end
        else
          # Ha a játékos húzott 3. lapot
          banker_draws = case banker_total
                         when 0, 1, 2 then true
                         when 3 then p3_val != 8
                         when 4 then [2, 3, 4, 5, 6, 7].include?(p3_val)
                         when 5 then [4, 5, 6, 7].include?(p3_val)
                         when 6 then [6, 7].include?(p3_val)
                         else false
                         end
          if banker_draws
            banker_cards << deck.pop
            banker_total = hand_value(banker_cards)
          end
        end
      end

      # Végeredmény meghatározása
      result = if player_total > banker_total
                 "player"
               elsif banker_total > player_total
                 "banker"
               else
                 "tie"
               end

      {
        player_cards: player_cards,
        banker_cards: banker_cards,
        player_score: player_total,
        banker_score: banker_total,
        result: result,
        natural: natural
      }
    end

    # Kiszámolja a kifizetést a fogadás típusa alapján
    def self.calculate_payout(bet_type, amount, round_result)
      outcome = round_result[:result] # "player", "banker", "tie"
      bet = bet_type.to_s.downcase

      if outcome == "tie"
        if bet == "tie"
          amount + (amount * 8) # 8:1 nyeremény
        elsif %w[player banker].include?(bet)
          amount # Döntetlen esetén a Player és Banker tét visszajár (Push)
        else
          0
        end
      elsif outcome == "player"
        if bet == "player"
          amount + amount # 1:1 nyeremény
        else
          0
        end
      elsif outcome == "banker"
        if bet == "banker"
          # 0.95:1 (5% ház jutalék levonás után)
          amount + (amount * 0.95).round
        else
          0
        end
      else
        0
      end
    end
  end
end

