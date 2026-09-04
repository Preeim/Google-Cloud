module Casino
  class TableManager
    BETTING_DURATION_SECONDS = 20
    PLAYER_TURN_DURATION_SECONDS = 30

    # Automatikusan elindítja a 20 másodperces fogadási visszaszámlálást, ha a játékos belép egy tétlen Blackjack asztalhoz
    def self.check_or_start_timer(table)
      return unless table.game_type == "blackjack"
      return if %w[maintenance resolving player_turns].include?(table.state)

      table.with_lock do
        if table.state == "idle" || (table.betting_closes_at.present? && table.betting_closes_at <= Time.current)
          table.update!(
            state: "betting",
            betting_closes_at: BETTING_DURATION_SECONDS.seconds.from_now
          )

          Casino::TableChannel.broadcast_to(table, {
            type: "timer_started",
            seconds_remaining: BETTING_DURATION_SECONDS,
            round_number: table.round_number
          })
        end
      end
    end

    def self.place_bet(table, profile, bet_type, amount)
      amount = amount.to_i
      return { success: false, error: "A tétnek minimum #{table.min_bet} zsetonnak kell lennie." } if amount < table.min_bet
      return { success: false, error: "A tét legfeljebb #{table.max_bet} zseton lehet." } if amount > table.max_bet
      return { success: false, error: "Nincs elegendő zsetonod a fogadáshoz." } unless profile.can_afford?(amount)

      bet_type_str = bet_type.to_s.downcase

      # Validáció a játéktípusok fogadási mezőire
      case table.game_type
      when "blackjack"
        return { success: false, error: "Érvénytelen ülőhely választás (1..3)." } unless %w[seat_1 seat_2 seat_3].include?(bet_type_str)
      when "baccarat"
        return { success: false, error: "Érvénytelen fogadási mező (player, banker, tie)." } unless %w[player banker tie].include?(bet_type_str)
      when "roulette"
        valid_roulette = %w[red black even odd 1-18 19-36 dozen_1 dozen_2 dozen_3 col_1 col_2 col_3] + (0..36).map(&:to_s)
        return { success: false, error: "Érvénytelen rulett mező." } unless valid_roulette.include?(bet_type_str)
      end

      bet = nil
      table.with_lock do
        return { success: false, error: "Az asztal jelenleg karbantartás alatt áll." } if table.state == "maintenance"
        return { success: false, error: "A lapok már kiosztásra kerültek erre a körre." } if %w[player_turns resolving].include?(table.state)

        if table.game_type == "blackjack"
          if table.bets.where(round_number: table.round_number, bet_type: bet_type_str, status: "pending").exists?
            return { success: false, error: "Ez az ülőhely már foglalt ebben a körben." }
          end
          if table.bets.where(round_number: table.round_number, casino_profile_id: profile.id, status: "pending").exists?
            return { success: false, error: "Már foglaltál ülőhelyet ebben a körben." }
          end
        end

        # Ha pihenő állapotban volt, indítjuk a 20 mp visszaszámlálást
        if table.state == "idle" || table.betting_closes_at.nil? || table.betting_closes_at <= Time.current
          table.update!(
            state: "betting",
            betting_closes_at: BETTING_DURATION_SECONDS.seconds.from_now
          )
        end

        # Zseton levonása zárolással
        profile.deduct_chips!(
          amount,
          transaction_type: "bet",
          game_type: table.game_type,
          metadata: { table_id: table.id, round_number: table.round_number, bet_type: bet_type_str }
        )

        # Tét rögzítése
        bet = table.bets.create!(
          casino_profile_id: profile.id,
          round_number: table.round_number,
          bet_type: bet_type_str,
          amount: amount,
          status: "pending"
        )
      end

      # Valós idejű WebSocket értesítés az asztalnak
      Casino::TableChannel.broadcast_to(table, {
        type: "bet_placed",
        user_name: profile.user.username,
        user_id: profile.user.id,
        profile_id: profile.id,
        bet_type: bet_type_str,
        amount: amount,
        round_number: table.round_number,
        seconds_remaining: table.seconds_remaining
      })

      { success: true, bet: bet, seconds_remaining: table.seconds_remaining }
    rescue => e
      { success: false, error: e.message }
    end

    # Blackjack osztás indítása a fogadási idő után
    def self.start_blackjack_deal(table)
      table.with_lock do
        current_bets = table.bets.where(round_number: table.round_number, status: "pending").includes(profile: :user)

        # Ha nem érkezett tét, visszaállunk készenlétbe
        if current_bets.empty?
          table.update!(state: "idle", betting_closes_at: nil)
          Casino::TableChannel.broadcast_to(table, {
            type: "table_idle",
            message: "Nem érkezett tét, a dealer vár a játékosokra."
          })
          return { success: false, error: "Nincs aktív tét az asztalon.", idle: true }
        end

        deck = BlackjackEngine.new_shuffled_deck
        dealer_cards = [deck.pop || BlackjackEngine.new_shuffled_deck.pop, deck.pop || BlackjackEngine.new_shuffled_deck.pop]

        players_data = {}
        current_bets.each do |bet|
          p_cards = [deck.pop || BlackjackEngine.new_shuffled_deck.pop, deck.pop || BlackjackEngine.new_shuffled_deck.pop]
          score = BlackjackEngine.hand_value(p_cards)
          is_bj = BlackjackEngine.blackjack?(p_cards)
          p_id = bet.casino_profile_id || bet.profile.id

          players_data[p_id.to_s] = {
            "profile_id" => p_id,
            "username" => bet.profile.user.username,
            "seat" => bet.bet_type,
            "amount" => bet.amount,
            "cards" => p_cards,
            "score" => score,
            "status" => is_bj ? "blackjack" : "playing"
          }
        end

        state_payload = {
          "deck" => deck,
          "dealer_cards" => dealer_cards,
          "dealer_visible_score" => BlackjackEngine.card_point(dealer_cards.first[:rank]),
          "players" => players_data
        }

        # Ha mindenkinek azonnal Blackjackje lett
        all_done = players_data.values.all? { |p| p["status"] != "playing" }

        if all_done
          table.update_state_data!(state_payload)
          resolve_blackjack_dealer(table)
        else
          table.update!(
            state: "player_turns",
            betting_closes_at: PLAYER_TURN_DURATION_SECONDS.seconds.from_now,
            state_data: state_payload.to_json
          )

          Casino::TableChannel.broadcast_to(table, {
            type: "blackjack_cards_dealt",
            round_number: table.round_number,
            dealer_visible_card: dealer_cards.first,
            dealer_visible_score: BlackjackEngine.card_point(dealer_cards.first[:rank]),
            seconds_remaining: PLAYER_TURN_DURATION_SECONDS,
            players: players_data
          })
        end

        { success: true, players: players_data }
      end
    end

    # Játékos döntése: lapkérés (hit) vagy megállás (stand)
    def self.player_action(table, profile, action)
      table.with_lock do
        return { success: false, error: "Nem a játékos döntési fázisban van az asztal." } unless table.state == "player_turns"

        state_data = table.current_state_data
        players = state_data["players"] || {}
        player = players[profile.id.to_s]

        return { success: false, error: "Nincs aktív téted ezen az asztalon ebben a körben." } unless player
        return { success: false, error: "Már megálltál vagy a kezed lezárult." } if %w[stood busted blackjack].include?(player["status"])

        deck = state_data["deck"] || []

        case action.to_s.downcase
        when "hit"
          card = deck.pop || BlackjackEngine.new_shuffled_deck.pop
          player["cards"] << card
          new_score = BlackjackEngine.hand_value(player["cards"])
          player["score"] = new_score

          if new_score > 21
            player["status"] = "busted"
          elsif new_score == 21
            player["status"] = "stood"
          end

        when "stand"
          player["status"] = "stood"
        else
          return { success: false, error: "Érvénytelen döntés (hit vagy stand)." }
        end

        state_data["deck"] = deck
        state_data["players"] = players
        table.update_state_data!(state_data)

        # Élő WebSocket értesítés a lap húzásáról / megállásról
        Casino::TableChannel.broadcast_to(table, {
          type: "player_action_taken",
          profile_id: profile.id,
          seat: player["seat"],
          username: player["username"],
          action: action,
          cards: player["cards"],
          score: player["score"],
          status: player["status"]
        })

        # Ellenőrizzük, hogy minden aktív játékos befejezte-e a döntéseit
        all_finished = players.values.all? { |p| %w[stood busted blackjack].include?(p["status"]) }
        if all_finished
          resolve_blackjack_dealer(table)
        end

        { success: true, player: player, all_finished: all_finished }
      end
    end

    # Osztó köre és Blackjack nyeremények kifizetése
    def self.resolve_blackjack_dealer(table)
      table.with_lock do
        state_data = table.current_state_data
        deck = state_data["deck"] || BlackjackEngine.new_shuffled_deck
        dealer_cards = state_data["dealer_cards"] || [deck.pop, deck.pop]
        players = state_data["players"] || {}

        # Ha nem minden játékos sokallt be, az osztó lapokat húz 17-ig
        any_player_active = players.values.any? { |p| p["status"] != "busted" }
        if any_player_active
          dealer_cards = BlackjackEngine.play_dealer_hand(dealer_cards, deck)
        end

        dealer_score = BlackjackEngine.hand_value(dealer_cards)
        winner_announcements = []
        payouts_summary = []

        current_bets = table.bets.where(round_number: table.round_number, status: "pending").includes(profile: :user)

        current_bets.each do |bet|
          p_id = bet.casino_profile_id || bet.profile.id
          p_data = players[p_id.to_s]
          next unless p_data

          p_cards = p_data["cards"]
          outcome = BlackjackEngine.evaluate_outcome(p_cards, dealer_cards, bet.amount)
          payout = outcome[:payout]
          profile = bet.profile

          if payout > 0
            profile.add_chips!(
              payout,
              transaction_type: "payout",
              game_type: "blackjack",
              metadata: { bet_id: bet.id, outcome: outcome }
            )
            bet.update!(payout: payout, status: outcome[:result] == "push" ? "push" : "won")
            profile.increment!(:total_won_rounds) if outcome[:result] != "push"

            if outcome[:result] == "blackjack"
              winner_announcements << "🔥 #{profile.user.username} BLACKJACKET ért el! Nyeremény: #{payout.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse} zseton (3:2)!"
            elsif outcome[:result] == "push"
              winner_announcements << "🤝 #{profile.user.username}: Döntetlen az osztóval! #{bet.amount} zseton visszajár."
            else
              winner_announcements << "🎉 #{profile.user.username} legyőzte az osztót és #{payout.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse} zsetont nyert!"
            end
          else
            bet.update!(payout: 0, status: "lost")
          end

          profile.increment!(:total_rounds_played)

          payouts_summary << {
            user_id: profile.user.id,
            user_name: profile.user.username,
            bet_amount: bet.amount,
            payout: payout,
            profit: payout - bet.amount,
            result: outcome[:result],
            player_score: outcome[:player_score],
            dealer_score: dealer_score
          }
        end

        # Ha senki sem nyert ebben a körben
        if winner_announcements.empty? && current_bets.any?
          winner_announcements << "💀 A Ház (Osztó) nyerte a kört! Egyik játékos sem nyert."
        end

        resolution_data = {
          dealer_cards: dealer_cards,
          dealer_score: dealer_score,
          players: players,
          winners: winner_announcements,
          payouts: payouts_summary
        }

        table.update!(
          state: "idle",
          round_number: table.round_number + 1,
          betting_closes_at: nil,
          state_data: resolution_data.to_json
        )

        Casino::TableChannel.broadcast_to(table, {
          type: "round_resolved",
          round_number: table.round_number - 1,
          game_type: "blackjack",
          outcome: resolution_data,
          dealer_cards: dealer_cards,
          dealer_score: dealer_score,
          winners: winner_announcements,
          payouts: payouts_summary
        })

        { success: true, outcome: resolution_data, winners: winner_announcements }
      end
    end

    # Rulett és Baccarat körök azonnali sorsolása
    def self.resolve_round(table)
      if table.game_type == "blackjack"
        # Ha a blackjacknél a fogadási idő után hívjuk meg: osztunk lapokat!
        if table.state == "betting" || table.state == "idle"
          return start_blackjack_deal(table)
        elsif table.state == "player_turns"
          table.with_lock do
            state_data = table.current_state_data
            players = state_data["players"] || {}
            all_done = players.values.all? { |p| %w[stood busted blackjack].include?(p["status"]) }
            time_expired = table.betting_closes_at.present? && table.betting_closes_at <= Time.current

            if all_done || time_expired
              # Ha lejárt a döntési idő, a még gondolkodó játékosokat automatikusan megállítjuk (stand)
              if time_expired && !all_done
                players.each do |_, p_data|
                  p_data["status"] = "stood" if p_data["status"] == "playing"
                end
                state_data["players"] = players
                table.update_state_data!(state_data)
              end
              return resolve_blackjack_dealer(table)
            else
              return { success: false, error: "A játékosok még nem fejezték be a lapkérést (Hit/Stand)." }
            end
          end
        end
      end

      table.with_lock do
        return { success: false, error: "Az asztal nem áll készen az elbírálásra." } unless %w[idle betting resolving].include?(table.state)

        table.update!(state: "resolving")
        current_bets = table.bets.where(round_number: table.round_number, status: "pending").includes(profile: :user)

        resolution_data = {}
        payouts_summary = []
        winner_announcements = []

        case table.game_type
        when "roulette"
          winning_number = RouletteEngine.spin
          color = RouletteEngine.color_for(winning_number)
          resolution_data = {
            winning_number: winning_number,
            color: color
          }

          current_bets.each do |bet|
            payout = RouletteEngine.calculate_payout(bet.bet_type, bet.amount, winning_number)
            process_bet_payout(bet, payout, resolution_data, payouts_summary, winner_announcements)
          end

        when "baccarat"
          baccarat_result = BaccaratEngine.play_round
          resolution_data = baccarat_result

          current_bets.each do |bet|
            payout = BaccaratEngine.calculate_payout(bet.bet_type, bet.amount, baccarat_result)
            process_bet_payout(bet, payout, resolution_data, payouts_summary, winner_announcements)
          end
        end

        if winner_announcements.empty? && current_bets.any?
          winner_announcements << "💀 Ebben a körben a Ház nyert, nem született nyertes tét."
        end

        resolution_data[:winners] = winner_announcements

        table.update!(
          state: "idle",
          round_number: table.round_number + 1,
          betting_closes_at: nil,
          state_data: resolution_data.to_json
        )

        Casino::TableChannel.broadcast_to(table, {
          type: "round_resolved",
          round_number: table.round_number - 1,
          game_type: table.game_type,
          outcome: resolution_data,
          winners: winner_announcements,
          payouts: payouts_summary
        })

        { success: true, outcome: resolution_data, winners: winner_announcements, payouts: payouts_summary }
      end
    end

    private

    def self.process_bet_payout(bet, payout, resolution_data, payouts_summary, winner_announcements)
      profile = bet.profile
      won = payout > 0
      is_push = payout == bet.amount

      if won
        profile.add_chips!(
          payout,
          transaction_type: "payout",
          game_type: bet.table.game_type,
          metadata: { bet_id: bet.id, outcome: resolution_data }
        )

        if is_push
          bet.update!(payout: payout, status: "push")
          winner_announcements << "🤝 #{profile.user.username}: Döntetlen (Push), a tét visszajár (#{bet.amount} zseton)."
        else
          bet.update!(payout: payout, status: "won")
          profile.increment!(:total_won_rounds)
          winner_announcements << "🎉 #{profile.user.username} nyert #{payout.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse} zsetont a(z) #{bet.bet_type.upcase} mezőn!"
        end
      else
        bet.update!(payout: 0, status: "lost")
      end

      profile.increment!(:total_rounds_played)

      payouts_summary << {
        user_id: profile.user.id,
        user_name: profile.user.username,
        bet_type: bet.bet_type,
        bet_amount: bet.amount,
        payout: payout,
        profit: payout - bet.amount,
        won: won && !is_push,
        push: is_push
      }
    end
  end
end
