module Chess
  class MatchChannel < ApplicationCable::Channel
    def subscribed
      @match = Match.find_by(uuid: params[:match_id])
      reject unless @match
      stream_for @match
    end

    def unsubscribed
      # Any cleanup needed when channel is closed
    end

    def make_move(data)
      begin
        @match.reload
        unless @match.active?
          transmit({ action: "error", message: "A játszma nem aktív vagy már befejeződött!" })
          return
        end

        if current_player_color == "spectator"
          raise "Nézők nem léphetnek!"
        end

        # Check timeout before processing move
        if @match.check_timeout!
          broadcast_game_over
          return
        end

        @match.make_move!(data["san_move"], data["fen"], data["pgn"], current_player_color, data)

        # Invalidate any pending draw or takeback offer once a move is made
        Rails.cache.delete("chess_match_draw_offer:#{@match.id}")
        Rails.cache.delete("chess_match_takeback_offer:#{@match.id}")

        Chess::MatchChannel.broadcast_to(@match, {
          action: "move",
          fen: @match.fen,
          pgn: @match.pgn,
          status: @match.status,
          white_time_left: @match.white_time_left,
          black_time_left: @match.black_time_left,
          last_move_at: @match.last_move_at&.iso8601,
          current_turn: @match.current_turn
        })

        if @match.completed?
          broadcast_game_over
        end
      rescue => e
        transmit({ action: "error", message: "Érvénytelen lépés: #{e.message}" })
      end
    end

    def offer_draw
      @match.reload
      return unless @match.active?
      return if current_player_color == "spectator"
      return unless Chess::Setting.current.allow_draw_offer?

      Rails.cache.write("chess_match_draw_offer:#{@match.id}", current_player_color, expires_in: 25.seconds)

      Chess::MatchChannel.broadcast_to(@match, {
        action: "draw_offered",
        by: current_user_or_guest_id,
        color: current_player_color
      })
    end

    def accept_draw
      @match.reload
      return unless @match.active?
      return if current_player_color == "spectator"

      offered_by = Rails.cache.read("chess_match_draw_offer:#{@match.id}")
      opponent_color = current_player_color == "white" ? "black" : "white"

      if offered_by.to_s != opponent_color
        transmit({ action: "error", message: "A döntetlen ajánlat lejárt vagy nem létezik!" })
        return
      end

      Rails.cache.delete("chess_match_draw_offer:#{@match.id}")
      @match.update!(status: "completed", termination_reason: "draw_agreed", winner: "draw")
      broadcast_game_over
    end

    def decline_draw
      @match.reload
      return unless @match.active?
      return if current_player_color == "spectator"

      Rails.cache.delete("chess_match_draw_offer:#{@match.id}")
      Chess::MatchChannel.broadcast_to(@match, {
        action: "draw_declined",
        by: current_user_or_guest_id,
        color: current_player_color
      })
    end

    def resign
      @match.reload
      return unless @match.active?
      return if current_player_color == "spectator"

      winner = current_player_color == "white" ? "black" : "white"
      @match.update!(status: "completed", termination_reason: "resign", winner: winner)
      broadcast_game_over
    end

    def request_takeback
      @match.reload
      return unless @match.active?
      return if current_player_color == "spectator"
      return unless Chess::Setting.current.allow_takeback?

      Rails.cache.write("chess_match_takeback_offer:#{@match.id}", current_player_color, expires_in: 25.seconds)

      Chess::MatchChannel.broadcast_to(@match, {
        action: "takeback_requested",
        by: current_user_or_guest_id,
        color: current_player_color
      })
    end

    def answer_takeback(data)
      @match.reload
      return unless @match.active?
      return if current_player_color == "spectator"

      requested_by = Rails.cache.read("chess_match_takeback_offer:#{@match.id}")
      opponent_color = current_player_color == "white" ? "black" : "white"

      if requested_by.to_s != opponent_color
        transmit({ action: "error", message: "A visszalépési kérelem lejárt vagy nem létezik!" })
        return
      end

      Rails.cache.delete("chess_match_takeback_offer:#{@match.id}")

      if data["accepted"]
        @match.undo_move!(requested_by)
        Chess::MatchChannel.broadcast_to(@match, {
          action: "takeback_accepted",
          fen: @match.fen,
          pgn: @match.pgn,
          white_time_left: @match.white_time_left,
          black_time_left: @match.black_time_left,
          last_move_at: @match.last_move_at&.iso8601,
          current_turn: @match.current_turn
        })
      else
        Chess::MatchChannel.broadcast_to(@match, { action: "takeback_rejected", color: current_player_color })
      end
    end

    def claim_timeout
      @match.reload
      return unless @match.active?
      
      if @match.check_timeout!
        broadcast_game_over
      end
    end

    private

    def broadcast_game_over
      reason_text = case @match.termination_reason
                    when "checkmate"
                      winner_name = @match.winner == "white" ? @match.white_player_name : @match.black_player_name
                      "Sakk-matt! Nyertes: #{winner_name}"
                    when "resign"
                      winner_name = @match.winner == "white" ? @match.white_player_name : @match.black_player_name
                      "Feladás. Nyertes: #{winner_name}"
                    when "timeout"
                      winner_name = @match.winner == "white" ? @match.white_player_name : @match.black_player_name
                      "Időtúllépés! Nyertes: #{winner_name}"
                    when "draw_agreed"
                      "Döntetlen közös megegyezéssel."
                    when "stalemate"
                      "Patt! A játszma döntetlen."
                    else
                      "A játszma véget ért."
                    end

      Chess::MatchChannel.broadcast_to(@match, {
        action: "game_over",
        reason: reason_text,
        winner: @match.winner,
        termination_reason: @match.termination_reason,
        status: @match.status
      })
    end

    def current_user_or_guest_id
      current_user&.id || effective_guest_id
    end

    def effective_guest_id
      guest_id.to_s.presence
    end

    def current_player_color
      # 1. Bejelentkezett felhasználó vizsgálata
      if current_user.present?
        return "white" if @match.white_user_id.present? && @match.white_user_id == current_user.id
        return "black" if @match.black_user_id.present? && @match.black_user_id == current_user.id
      end

      # 2. Vendég azonosító vizsgálata (Connection azonosító vagy feliratkozási paraméter)
      gid = effective_guest_id
      if gid.present?
        return "white" if @match.white_guest_id.present? && @match.white_guest_id.to_s == gid
        return "black" if @match.black_guest_id.present? && @match.black_guest_id.to_s == gid
      end

      "spectator"
    end
  end
end
