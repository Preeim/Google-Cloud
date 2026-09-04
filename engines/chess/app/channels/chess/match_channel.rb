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
        @match.make_move!(data["san_move"], data["fen"], data["pgn"])
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
      Chess::MatchChannel.broadcast_to(@match, {
        action: "draw_offered",
        by: current_user_or_guest_id
      })
    end

    def accept_draw
      @match.update!(status: "completed", termination_reason: "draw_agreed", winner: "draw")
      Chess::MatchChannel.broadcast_to(@match, { action: "game_over", reason: "Döntetlen megegyezés" })
    end

    def resign
      winner = current_player_color == "white" ? "black" : "white"
      @match.update!(status: "completed", termination_reason: "resign", winner: winner)
      Chess::MatchChannel.broadcast_to(@match, { action: "game_over", reason: "Feladás" })
    end

    def request_takeback
      Chess::MatchChannel.broadcast_to(@match, {
        action: "takeback_requested",
        by: current_user_or_guest_id
      })
    end

    def answer_takeback(data)
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
