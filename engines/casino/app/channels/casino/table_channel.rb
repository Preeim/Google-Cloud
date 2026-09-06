module Casino
  class TableChannel < ApplicationCable::Channel
    def subscribed
      reject and return unless authorized_user?

      @table = Casino::Table.find_by(slug: params[:table_id]) || Casino::Table.find_by(id: params[:table_id])
      if @table
        stream_for @table

        # Játékos online jelenlétének regisztrálása az asztalnál
        Casino::TableManager.register_presence(@table.id, current_user.id)

        # Értesítés az asztalnak, hogy új játékos lépett be
        Casino::TableChannel.broadcast_to(@table, {
          type: "player_joined",
          user_id: current_user.id,
          username: current_user.username,
          online_count: Casino::TableManager.online_players_count(@table.id)
        })
      else
        reject
      end
    end

    def unsubscribed
      if @table && current_user
        # Játékos jelenlétének törlése
        Casino::TableManager.unregister_presence(@table.id, current_user.id)

        Casino::TableChannel.broadcast_to(@table, {
          type: "player_left",
          user_id: current_user.id,
          username: current_user.username,
          online_count: Casino::TableManager.online_players_count(@table.id)
        })
      end
    end


    def place_bet(data)
      return unless authorized_user?
      if rate_limited?
        transmit({ type: "bet_response", success: false, error: "Túl gyors művelet! Kérjük lassíts egy pillanatra." })
        return
      end

      profile = Casino::Profile.find_by(user_id: current_user.id)
      return unless profile

      res = Casino::TableManager.place_bet(@table, profile, data["bet_type"], data["amount"])
      transmit({ type: "bet_response", success: res[:success], error: res[:error], chips: profile.reload.chips })
    end

    # Blackjack döntés: "hit" (lapkérés), "stand" (megállás) vagy "double" (duplázás)
    def player_action(data)
      return unless authorized_user?
      if rate_limited?
        transmit({ type: "action_response", success: false, error: "Túl gyors művelet! Kérjük lassíts egy pillanatra." })
        return
      end

      profile = Casino::Profile.find_by(user_id: current_user.id)
      return unless profile

      res = Casino::TableManager.player_action(@table, profile, data["action"])
      transmit({ type: "action_response", success: res[:success], error: res[:error] })
    end

    def spin_wheel(data)
      return unless authorized_user?
      if rate_limited?
        transmit({ type: "resolve_response", success: false, error: "Túl gyors művelet! Kérjük lassíts egy pillanatra." })
        return
      end

      profile = Casino::Profile.find_by(user_id: current_user.id)
      return unless profile

      # Csak admin, a körben aktív téttel rendelkező játékos, vagy lejárt fogadási időzítő esetén indítható el
      has_active_bet = @table.current_bets.where(casino_profile_id: profile.id).exists?
      timer_expired = @table.betting_closes_at.present? && @table.betting_closes_at <= Time.current
      unless current_user.admin? || has_active_bet || timer_expired
        transmit({ type: "resolve_response", success: false, error: "Nincs aktív téted ezen az asztalon a sorsolás indításához." })
        return
      end


      res = Casino::TableManager.resolve_round(@table)
      transmit({ type: "resolve_response", success: res[:success], error: res[:error] })
    end


    private

    def authorized_user?
      current_user && current_user.active? && !current_user.locked? && current_user.can_access_app?("casino")
    end

    # WebSocket spam védelem: minimum 250ms szünetet ír elő műveletek között
    def rate_limited?
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if @last_action_at && (now - @last_action_at) < 0.25
        true
      else
        @last_action_at = now
        false
      end
    end
  end
end


