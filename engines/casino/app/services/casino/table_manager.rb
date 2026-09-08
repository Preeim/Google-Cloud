module Casino
  class TableManager
    BETTING_DURATION_SECONDS = 20
    PLAYER_TURN_DURATION_SECONDS = 30

    PRESENCE_CACHE_KEY_PREFIX = "casino_table_presence_".freeze
    PRESENCE_EXPIRY = 30.minutes

    def self.presence_cache_key(table_id)
      "#{PRESENCE_CACHE_KEY_PREFIX}#{table_id}"
    end

    def self.register_presence(table_id, user_id)
      return unless table_id && user_id
      key = presence_cache_key(table_id)
      presence = Rails.cache.read(key) || {}
      presence[user_id.to_s] = (presence[user_id.to_s].to_i) + 1
      Rails.cache.write(key, presence, expires_in: PRESENCE_EXPIRY)
    end

    def self.unregister_presence(table_id, user_id)
      return unless table_id && user_id
      key = presence_cache_key(table_id)
      presence = Rails.cache.read(key) || {}
      if presence[user_id.to_s]
        count = presence[user_id.to_s].to_i - 1
        if count <= 0
          presence.delete(user_id.to_s)
        else
          presence[user_id.to_s] = count
        end
      end
      if presence.empty?
        Rails.cache.delete(key)
      else
        Rails.cache.write(key, presence, expires_in: PRESENCE_EXPIRY)
      end
    end

    def self.has_online_players?(table_id)
      return false unless table_id
      presence = Rails.cache.read(presence_cache_key(table_id)) || {}
      presence.any? { |_uid, count| count.to_i > 0 }
    end

    def self.online_players_count(table_id)
      return 0 unless table_id
      presence = Rails.cache.read(presence_cache_key(table_id)) || {}
      presence.count { |_uid, count| count.to_i > 0 }
    end

    # Csak akkor indítunk visszaszámlálást, ha már van aktív tét az asztalon
    def self.check_or_start_timer(table)
      return unless table.game_type == "blackjack"
      return if %w[maintenance resolving player_turns].include?(table.state)

      table.with_lock do
        # Csak akkor indítjuk el, ha van leadott tét az asztalon
        return unless table.current_bets.exists?

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
      return { success: false, error: "A tétnek pozitív számnak kell lennie.", error_code: "invalid_amount" } if amount <= 0
      return { success: false, error: "A tétnek minimum #{table.min_bet} zsetonnak kell lennie.", error_code: "below_min_bet", min_bet: table.min_bet } if amount < table.min_bet
      return { success: false, error: "A tét legfeljebb #{table.max_bet} zseton lehet.", error_code: "above_max_bet", max_bet: table.max_bet } if amount > table.max_bet

      bet_type_str = bet_type.to_s.downcase.strip

      # Validáció a játéktípusok fogadási mezőire
      case table.game_type
      when "blackjack"
        return { success: false, error: "Érvénytelen ülőhely választás (1..3)." } unless %w[seat_1 seat_2 seat_3].include?(bet_type_str)
      when "baccarat"
        return { success: false, error: "Érvénytelen fogadási mező (player, banker, tie)." } unless %w[player banker tie].include?(bet_type_str)
      when "roulette"
        valid_roulette = %w[red black even odd 1-18 19-36 low high dozen_1 dozen_2 dozen_3 1-12 13-24 25-36 col_1 col_2 col_3] + (0..36).map(&:to_s)
        return { success: false, error: "Érvénytelen rulett mező." } unless valid_roulette.include?(bet_type_str)
      else
        return { success: false, error: "Ismeretlen játéktípus." }
      end

      bet = nil
      needs_timer = false
      insufficient_error = nil

      table.with_lock do
        table.reload
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

        # Ha pihenő állapotban volt, vagy a korábbi számláló tét nélkül járt le: indítjuk az első tét miatti 20 mp visszaszámlálást
        needs_timer = table.state == "idle" || table.betting_closes_at.nil? || (table.betting_closes_at <= Time.current && table.current_bets.empty?)

        if needs_timer
          table.update!(
            state: "betting",
            betting_closes_at: BETTING_DURATION_SECONDS.seconds.from_now
          )
        elsif table.betting_closes_at <= Time.current
          return { success: false, error: "A fogadási idő már lejárt erre a körre, a sorsolás folyamatban van." }
        end

        # Zseton levonása zárolással és fedezet-ellenőrzéssel
        profile.with_lock do
          if profile.can_afford?(amount)
            profile.deduct_chips!(
              amount,
              transaction_type: "bet",
              game_type: table.game_type,
              metadata: { table_id: table.id, round_number: table.round_number, bet_type: bet_type_str }
            )
          else
            insufficient_error = {
              success: false,
              error: "Nincs elegendő zsetonod a fogadáshoz! Elérhető egyenleged: #{profile.chips} zseton.",
              error_code: "insufficient_chips",
              available_chips: profile.chips,
              required_amount: amount,
              min_bet: table.min_bet
            }
          end
        end

        return insufficient_error if insufficient_error

        # Tét rögzítése
        bet = table.bets.create!(
          casino_profile_id: profile.id,
          round_number: table.round_number,
          bet_type: bet_type_str,
          amount: amount,
          status: "pending"
        )
      end


      # Ha ez volt az első tét, kiküldjük a visszaszámlálás indító eseményt is
      if needs_timer
        Casino::TableChannel.broadcast_to(table, {
          type: "timer_started",
          seconds_remaining: BETTING_DURATION_SECONDS,
          round_number: table.round_number
        })
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
    def self.start_blackjack_deal(table, force: false)
      table.with_lock do
        table.reload
        return { success: false, error: "A lapok már kiosztásra kerültek erre a körre." } unless %w[idle betting].include?(table.state)

        current_bets = table.bets.where(round_number: table.round_number, status: "pending").includes(profile: :user)

        # Ha nem érkezett tét a fogadási idő alatt
        if current_bets.empty?
          if has_online_players?(table.id)
            # A számláló végéig senki nem rakott semmit, de van online játékos -> újraindul a 20 mp
            table.update!(
              state: "betting",
              betting_closes_at: BETTING_DURATION_SECONDS.seconds.from_now
            )
            Casino::TableChannel.broadcast_to(table, {
              type: "timer_started",
              seconds_remaining: BETTING_DURATION_SECONDS,
              round_number: table.round_number,
              message: "Nem érkezett tét, a fogadási idő újraindult!"
            })
            return { success: false, restarted: true, error: "Nem érkezett tét, a fogadási idő újraindult." }
          else
            # Nincs online játékos az asztalnál -> pihenő állapotba állunk
            table.update!(state: "idle", betting_closes_at: nil)
            Casino::TableChannel.broadcast_to(table, {
              type: "table_idle",
              message: "Nem érkezett tét, a dealer vár a játékosokra."
            })
            return { success: false, error: "Nincs aktív tét az asztalon.", idle: true }
          end
        end


        # Ha a fogadási idő még ketyeg és nem minden szék foglalt
        if !force && table.betting_closes_at.present? && table.betting_closes_at > Time.current && current_bets.size < 3
          return { success: false, error: "A fogadási idő még tart (#{table.seconds_remaining} mp maradt a többi játékosnak)." }
        end

        deck = BlackjackEngine.new_shuffled_deck(6)
        dealer_cards = [deck.pop, deck.pop]

        players_data = {}
        current_bets.each do |bet|
          p_cards = [deck.pop, deck.pop]
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

        dealer_rank = dealer_cards.first[:rank] || dealer_cards.first["rank"]
        dealer_vis_score = BlackjackEngine.card_point(dealer_rank)

        state_payload = {
          "deck" => deck,
          "dealer_cards" => dealer_cards,
          "dealer_visible_score" => dealer_vis_score,
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
            dealer_visible_score: dealer_vis_score,
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
        table.reload
        return { success: false, error: "Nem a játékos döntési fázisban van az asztal." } unless table.state == "player_turns"

        state_data = table.current_state_data
        players = state_data["players"] || {}
        player = players[profile.id.to_s]

        return { success: false, error: "Nincs aktív téted ezen az asztalon ebben a körben." } unless player
        return { success: false, error: "Már megálltál vagy a kezed lezárult." } if %w[stood busted blackjack].include?(player["status"])

        deck = state_data["deck"] || []
        deck = BlackjackEngine.new_shuffled_deck(6) if deck.empty?

        case action.to_s.downcase.strip
        when "hit"
          card = deck.pop || BlackjackEngine.new_shuffled_deck(6).pop
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

        when "double"
          return { success: false, error: "Duplázni csak a kezdeti 2 lap meglétekor lehet." } unless player["cards"].size == 2
          orig_amount = player["amount"].to_i

          profile.with_lock do
            unless profile.can_afford?(orig_amount)
              return {
                success: false,
                error: "Nincs elég zsetonod a tét megduplázásához! Szükséges: #{orig_amount} zseton, elérhető: #{profile.chips} zseton.",
                error_code: "insufficient_chips",
                available_chips: profile.chips,
                required_amount: orig_amount
              }
            end


            # Kiegészítő tét levonása zárolással
            profile.deduct_chips!(
              orig_amount,
              transaction_type: "bet",
              game_type: "blackjack",
              metadata: { table_id: table.id, round_number: table.round_number, action: "double_down" }
            )
          end

          # Tét rekord összegének és kéz adatainak frissítése
          bet = table.bets.find_by(round_number: table.round_number, casino_profile_id: profile.id, status: "pending")
          bet&.update!(amount: orig_amount * 2)
          player["amount"] = orig_amount * 2

          # Pontosan egyetlen lap kiosztása
          card = deck.pop || BlackjackEngine.new_shuffled_deck(6).pop
          player["cards"] << card
          new_score = BlackjackEngine.hand_value(player["cards"])
          player["score"] = new_score

          if new_score > 21
            player["status"] = "busted"
          else
            player["status"] = "stood"
          end

        else
          return { success: false, error: "Érvénytelen döntés (hit, stand vagy double)." }
        end

        state_data["deck"] = deck
        state_data["players"] = players
        table.update_state_data!(state_data)

        # Élő WebSocket értesítés a lap húzásáról / megállásról / duplázásról
        Casino::TableChannel.broadcast_to(table, {
          type: "player_action_taken",
          profile_id: profile.id,
          seat: player["seat"],
          username: player["username"],
          action: action,
          cards: player["cards"],
          score: player["score"],
          status: player["status"],
          amount: player["amount"]
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
        table.reload
        return { success: false, error: "Az asztal már nincs játékban." } unless table.state == "player_turns"

        state_data = table.current_state_data
        deck = state_data["deck"] || BlackjackEngine.new_shuffled_deck(6)
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
            chips_after: profile.reload.chips,
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

        has_online = has_online_players?(table.id)
        next_state = has_online ? "betting" : "idle"
        next_close = has_online ? (4 + BETTING_DURATION_SECONDS).seconds.from_now : nil

        table.update!(
          state: next_state,
          round_number: table.round_number + 1,
          betting_closes_at: next_close,
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
          payouts: payouts_summary,
          next_round: has_online,
          betting_duration: BETTING_DURATION_SECONDS
        })


        { success: true, outcome: resolution_data, winners: winner_announcements, payouts: payouts_summary }
      end
    end

    # Rulett, Baccarat és Blackjack körök sorsolása
    def self.resolve_round(table, force: false)
      table.with_lock do
        table.reload

        return { success: false, error: "Az asztal karbantartás alatt áll." } if table.state == "maintenance"
        return { success: false, error: "A kör elbírálása már folyamatban van." } if table.state == "resolving"
        return { success: false, error: "Nincs aktív fogadási kör az asztalon.", idle: true } if table.state == "idle"

        if table.game_type == "blackjack"
          if table.state == "betting"
            return start_blackjack_deal(table, force: force)
          elsif table.state == "player_turns"
            state_data = table.current_state_data
            players = state_data["players"] || {}
            all_done = players.values.all? { |p| %w[stood busted blackjack].include?(p["status"]) }
            time_expired = table.betting_closes_at.present? && table.betting_closes_at <= Time.current

            if all_done || time_expired || force
              if !all_done
                players.each do |_, p_data|
                  p_data["status"] = "stood" if p_data["status"] == "playing"
                end
                state_data["players"] = players
                table.update_state_data!(state_data)
              end
              return resolve_blackjack_dealer(table)
            else
              return { success: false, error: "A játékosok még nem fejezték be a lapkérést (Hit/Stand/Double)." }
            end
          else
            return { success: false, error: "Az asztal állapota (#{table.state}) nem engedélyezi a sorsolást." }
          end
        end

        # Roulette és Baccarat sorsolás
        current_bets = table.bets.where(round_number: table.round_number, status: "pending").includes(profile: :user)
        if current_bets.empty?
          if has_online_players?(table.id)
            table.update!(
              state: "betting",
              betting_closes_at: BETTING_DURATION_SECONDS.seconds.from_now
            )
            Casino::TableChannel.broadcast_to(table, {
              type: "timer_started",
              seconds_remaining: BETTING_DURATION_SECONDS,
              round_number: table.round_number,
              message: "Nem érkezett tét, a fogadási idő újraindult!"
            })
            return { success: false, restarted: true, error: "Nem érkezett tét, a fogadási idő újraindult." }
          else
            table.update!(state: "idle", betting_closes_at: nil)
            Casino::TableChannel.broadcast_to(table, {
              type: "table_idle",
              message: "Nem érkezett tét, az asztal várakozik a játékosokra."
            })
            return { success: false, error: "Nincs aktív tét az asztalon.", idle: true }
          end
        end


        # Ha a fogadási idő még tart
        if !force && table.state == "betting" && table.betting_closes_at.present? && table.betting_closes_at > Time.current
          return { success: false, error: "A fogadási idő még tart (#{table.seconds_remaining} mp maradt)." }
        end

        table.update!(state: "resolving")

        resolution_data = {}
        payouts_summary = []
        winner_announcements = []
        played_profile_ids = Set.new
        won_profile_ids = Set.new

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
            played_profile_ids << bet.casino_profile_id
            won_profile_ids << bet.casino_profile_id if payout > bet.amount
          end

        when "baccarat"
          baccarat_result = BaccaratEngine.play_round
          resolution_data = baccarat_result

          current_bets.each do |bet|
            payout = BaccaratEngine.calculate_payout(bet.bet_type, bet.amount, baccarat_result)
            process_bet_payout(bet, payout, resolution_data, payouts_summary, winner_announcements)
            played_profile_ids << bet.casino_profile_id
            won_profile_ids << bet.casino_profile_id if payout > bet.amount
          end
        end

        # Profil statisztikák körönként pontosan 1-szeri növelése ID alapján
        Casino::Profile.where(id: played_profile_ids.to_a).find_each { |p| p.increment!(:total_rounds_played) }
        Casino::Profile.where(id: won_profile_ids.to_a).find_each { |p| p.increment!(:total_won_rounds) }

        if winner_announcements.empty? && current_bets.any?
          winner_announcements << "💀 Ebben a körben a Ház nyert, nem született nyertes tét."
        end

        resolution_data[:winners] = winner_announcements

        has_online = has_online_players?(table.id)
        next_state = has_online ? "betting" : "idle"
        next_close = has_online ? (4 + BETTING_DURATION_SECONDS).seconds.from_now : nil

        table.update!(
          state: next_state,
          round_number: table.round_number + 1,
          betting_closes_at: next_close,
          state_data: resolution_data.to_json
        )

        Casino::TableChannel.broadcast_to(table, {
          type: "round_resolved",
          round_number: table.round_number - 1,
          game_type: table.game_type,
          outcome: resolution_data,
          winners: winner_announcements,
          payouts: payouts_summary,
          next_round: has_online,
          betting_duration: BETTING_DURATION_SECONDS
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
          winner_announcements << "🎉 #{profile.user.username} nyert #{payout.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse} zsetont a(z) #{bet.bet_type.upcase} mezőn!"
        end
      else
        bet.update!(payout: 0, status: "lost")
      end

      payouts_summary << {
        user_id: profile.user.id,
        user_name: profile.user.username,
        chips_after: profile.reload.chips,
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
