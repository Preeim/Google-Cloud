require "securerandom"

module Casino
  class RouletteEngine
    RED_NUMBERS = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36].freeze
    BLACK_NUMBERS = [2, 4, 6, 8, 10, 11, 13, 15, 17, 20, 22, 24, 26, 28, 29, 31, 33, 35].freeze

    def self.spin
      SecureRandom.random_number(37) # 0..36
    end

    def self.color_for(number)
      return "green" if number == 0
      RED_NUMBERS.include?(number) ? "red" : "black"
    end

    # Kiszámítja a kifizetési szorzót egy adott tét típusra és nyerő számra.
    # Ha nyer, visszadja a nyeremény teljes összegét (tét + nettó profit).
    # Ha veszít, 0-t ad vissza.
    def self.calculate_payout(bet_type, amount, winning_number)
      win = false
      multiplier = 0 # Nettó nyereményszorzó (pl. 35x a straight-nél)

      case bet_type.to_s.downcase
      when "red"
        win = RED_NUMBERS.include?(winning_number)
        multiplier = 1
      when "black"
        win = BLACK_NUMBERS.include?(winning_number)
        multiplier = 1
      when "even"
        win = winning_number != 0 && winning_number.even?
        multiplier = 1
      when "odd"
        win = winning_number != 0 && winning_number.odd?
        multiplier = 1
      when "low", "1-18"
        win = (1..18).include?(winning_number)
        multiplier = 1
      when "high", "19-36"
        win = (19..36).include?(winning_number)
        multiplier = 1
      when "dozen_1", "1-12"
        win = (1..12).include?(winning_number)
        multiplier = 2
      when "dozen_2", "13-24"
        win = (13..24).include?(winning_number)
        multiplier = 2
      when "dozen_3", "25-36"
        win = (25..36).include?(winning_number)
        multiplier = 2
      when "col_1"
        win = winning_number > 0 && winning_number % 3 == 1
        multiplier = 2
      when "col_2"
        win = winning_number > 0 && winning_number % 3 == 2
        multiplier = 2
      when "col_3"
        win = winning_number > 0 && winning_number % 3 == 0
        multiplier = 2
      else
        # Egyedi szám fogadás (pl. "17", "0", stb.)
        if bet_type.to_s =~ /\A\d+\z/
          chosen = bet_type.to_i
          if chosen == winning_number
            win = true
            multiplier = 35
          end
        end
      end

      if win
        # Teljes kifizetés: Tét visszakapása + nettó profit
        amount + (amount * multiplier)
      else
        0
      end
    end
  end
end

