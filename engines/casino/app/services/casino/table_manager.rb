module Casino
  class TableManager
    BETTING_DURATION_SECONDS = 20

    def self.place_bet(table, profile, bet_type, amount)
      amount = amount.to_i
      return { success: false, error: "A tétnek minimum #{table.min_bet} zsetonnak kell lennie." } if amount < table.min_bet
      return { success: false, error: "A tét legfeljebb #{table.max_bet} zseton lehet." } if amount > table.max_bet
      return { success: false, error: "Nincs elegendő zsetonod a fogadáshoz." } unless profile.can_afford?(amount)
      return { success: false, error: "Az asztal jelenleg karbantartás alatt áll." } if table.state == "maintenance"
      return { success: false, error: "A fogadási idő erre a körre már lezárult." } if table.state == "resolving"

      bet = nil
      table.with_lock do
        # Ha az asztal pihenő (idle) állapotban volt, most elindítjuk a fogadási időzítőt
        if table.state == "idle" || table.betting_closes_at.nil? || table.betting_closes_at <= Time.current
          table.update!(
            state: "betting",
            betting_closes_at: BETTING_DURATION_SECONDS.seconds.from_now
          )
        end

        # Zseton levonása atomi tranzakcióban
        profile.deduct_chips!(
          amount,
          transaction_type: "bet",
          game_type: table.game_type,
          metadata: { table_id: table.id, round_number: table.round_number, bet_type: bet_type }
        )

        # Tét rögzítése
        bet = table.bets.create!(
          profile: profile,
          round_number: table.round_number,
          bet_type: bet_type,
          amount: amount,
          status: "pending"
        )
      end

      # Valós idejű WebSocket értesítés az asztalnak
      Casino::TableChannel.broadcast_to(table, {
        type: "bet_placed",
        user_name: profile.user.username,
        user_id: profile.user.id,
        bet_type: bet_type,
        amount: amount,
        round_number: table.round_number,
        seconds_remaining: table.seconds_remaining
      })

      { success: true, bet: bet, seconds_remaining: table.seconds_remaining }
    rescue => e
      { success: false, error: e.message }
    end

    def self.resolve_round(table)
      table.with_lock do
        return { success: false, error: "Az asztal nem áll készen az elbírálásra." } unless %w[idle betting resolving].include?(table.state)

        table.update!(state: "resolving")
        current_bets = table.bets.where(round_number: table.round_number, status: "pending").includes(profile: :user)

        resolution_data = {}
        payouts_summary = []

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
            process_bet_payout(bet, payout, resolution_data, payouts_summary)
          end

        when "baccarat"
          baccarat_result = BaccaratEngine.play_round
          resolution_data = baccarat_result

          current_bets.each do |bet|
            payout = BaccaratEngine.calculate_payout(bet.bet_type, bet.amount, baccarat_result)
            process_bet_payout(bet, payout, resolution_data, payouts_summary)
          end

        when "blackjack"
          deck = BlackjackEngine.new_shuffled_deck
          dealer_initial = [deck.pop, deck.pop]
          dealer_full = BlackjackEngine.play_dealer_hand(dealer_initial, deck)

          resolution_data = {
            dealer_cards: dealer_full,
            dealer_score: BlackjackEngine.hand_value(dealer_full)
          }

          current_bets.each do |bet|
            # Minden játékos kap egy 2-lapos kezet, vagy ha lapot kért
            player_cards = [deck.pop, deck.pop]
            # Ha 16 alatt van, automatikusan még egy lapot húzunk a demó/gyors asztalon
            player_cards << deck.pop if BlackjackEngine.hand_value(player_cards) < 14

            outcome = BlackjackEngine.evaluate_outcome(player_cards, dealer_full, bet.amount)
            bet_data = resolution_data.merge(
              player_cards: player_cards,
              player_score: outcome[:player_score],
              outcome_result: outcome[:result]
            )
            process_bet_payout(bet, outcome[:payout], bet_data, payouts_summary)
          end
        end

        # Kör befejezése és új kör előkészítése
        table.update!(
          state: "idle",
          round_number: table.round_number + 1,
          betting_closes_at: nil,
          state_data: resolution_data.to_json
        )

        # Valós idejű eredményközvetítés
        Casino::TableChannel.broadcast_to(table, {
          type: "round_resolved",
          round_number: table.round_number - 1,
          game_type: table.game_type,
          outcome: resolution_data,
          payouts: payouts_summary
        })

        { success: true, outcome: resolution_data, payouts: payouts_summary }
      end
    end

    private

    def self.process_bet_payout(bet, payout, resolution_data, payouts_summary)
      profile = bet.profile
      won = payout > 0

      if won
        profile.add_chips!(
          payout,
          transaction_type: "payout",
          game_type: bet.table.game_type,
          metadata: { bet_id: bet.id, outcome: resolution_data }
        )
        bet.update!(payout: payout, status: "won")
        profile.increment!(:total_won_rounds)
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
        won: won
      }
    end
  end
end

