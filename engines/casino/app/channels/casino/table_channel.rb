module Casino
  class TableChannel < ApplicationCable::Channel
    def subscribed
      @table = Casino::Table.find_by(id: params[:table_id])
      if @table
        stream_for @table
        # Értesítés az asztalnak, hogy új játékos lépett be
        if current_user
          Casino::TableChannel.broadcast_to(@table, {
            type: "player_joined",
            user_id: current_user.id,
            username: current_user.username
          })
        end
      else
        reject
      end
    end

    def unsubscribed
      if @table && current_user
        Casino::TableChannel.broadcast_to(@table, {
          type: "player_left",
          user_id: current_user.id,
          username: current_user.username
        })
      end
    end

    def place_bet(data)
      return unless current_user
      profile = Casino::Profile.find_by(user_id: current_user.id)
      return unless profile

      res = Casino::TableManager.place_bet(@table, profile, data["bet_type"], data["amount"])
      transmit({ type: "bet_response", success: res[:success], error: res[:error], chips: profile.reload.chips })
    end

    def spin_wheel(data)
      return unless current_user
      # Ha lejárt az idő vagy a játékosok készen állnak
      res = Casino::TableManager.resolve_round(@table)
      transmit({ type: "resolve_response", success: res[:success], error: res[:error] })
    end
  end
end

