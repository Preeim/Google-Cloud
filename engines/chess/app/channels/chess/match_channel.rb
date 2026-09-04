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
        # Biztonsági ellenőrzés: csak az a játékos léphet, aki jön
        if current_player_color == "spectator"
          raise "Nézők nem léphetnek!"
        end
        
        # A Ruby chess gem ellenőrzi, hogy kinek a köre jön a PGN alapján, 
        # de nekünk ellenőriznünk kell, hogy a jelenlegi játékos küldi-e a lépést.
        # Ehhez a tábla állását le kell kérdeznünk. 
        # Mivel a model amúgy is felépíti a játékot, ott is validálhatnánk, de legegyszerűbb,
        # ha átadjuk a current_player_color-t a make_move! metódusnak.
        @match.make_move!(data["san_move"], data["fen"], data["pgn"], current_player_color)
        
        Chess::MatchChannel.broadcast_to(@match, {
          action: "move",
          fen: @match.fen,
          pgn: @match.pgn,
          status: @match.status
        })
      rescue => e
        # Invalid move
        transmit({ action: "error", message: "Érvénytelen lépés: #{e.message}" })
      end
    end

    def offer_draw
      @match.reload
      return if current_player_color == "spectator"
      Chess::MatchChannel.broadcast_to(@match, {
        action: "draw_offered",
        by: current_user_or_guest_id
      })
    end

    def accept_draw
      @match.reload
      return if current_player_color == "spectator"
      @match.update!(status: "completed", termination_reason: "draw_agreed", winner: "draw")
      Chess::MatchChannel.broadcast_to(@match, { action: "game_over", reason: "Döntetlen megegyezés" })
    end

    def resign
      @match.reload
      return if current_player_color == "spectator"
      winner = current_player_color == "white" ? "black" : "white"
      @match.update!(status: "completed", termination_reason: "resign", winner: winner)
      Chess::MatchChannel.broadcast_to(@match, { action: "game_over", reason: "Feladás" })
    end

    def request_takeback
      @match.reload
      return if current_player_color == "spectator"
      Chess::MatchChannel.broadcast_to(@match, {
        action: "takeback_requested",
        by: current_user_or_guest_id
      })
    end

    def answer_takeback(data)
      @match.reload
      return if current_player_color == "spectator"
      if data["accepted"]
        @match.undo_move!
        Chess::MatchChannel.broadcast_to(@match, {
          action: "takeback_accepted",
          fen: @match.fen,
          pgn: @match.pgn
        })
      else
        Chess::MatchChannel.broadcast_to(@match, { action: "takeback_rejected" })
      end
    end

    private

    def current_user_or_guest_id
      current_user&.id || guest_id
    end

    def current_player_color
      if current_user
        return "white" if @match.white_user_id == current_user.id
        return "black" if @match.black_user_id == current_user.id
      else
        return "white" if @match.white_guest_id == guest_id
        return "black" if @match.black_guest_id == guest_id
      end
      "spectator"
    end
  end
end
