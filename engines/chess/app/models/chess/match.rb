module Chess
  class Match < ApplicationRecord
    self.table_name = "chess_matches"

    # Enums
    enum :status, { pending: "pending", active: "active", completed: "completed", aborted: "aborted" }, default: "pending"
    enum :winner, { white: "white", black: "black", draw: "draw" }
    enum :termination_reason, { checkmate: "checkmate", resign: "resign", timeout: "timeout", draw_agreed: "draw_agreed", stalemate: "stalemate" }

    # Callbacks
    before_validation :generate_uuid, on: :create
    
    # Validations
    validates :uuid, presence: true, uniqueness: true
    validates :status, presence: true

    # Helpes
    def white_player_name
      if white_user_id
        # Using Core User model. Note: In a true decoupled monolith, you might want to fetch this via a service.
        User.find_by(id: white_user_id)&.username || "Unknown"
      else
        "Vendég ##{white_guest_id.to_s[0..3]}"
      end
    end

    def black_player_name
      if black_user_id
        User.find_by(id: black_user_id)&.username || "Unknown"
      else
        "Vendég ##{black_guest_id.to_s[0..3]}"
      end
    end

    private

    def generate_uuid
      self.uuid ||= SecureRandom.uuid
    end
    
    public

    # Helper to parse moves from PGN safely regardless of header tags or comments
    def parsed_played_moves
      clean = self.pgn.to_s.gsub(/\[.*?\]/m, '')
      clean = clean.gsub(/\{.*?\}/m, '')
      moves = clean.gsub(/\d+\.+/, '').split
      moves.reject { |m| %w[1-0 0-1 1/2-1/2 *].include?(m) }
    end

    # Helper for current turn
    def current_turn
      parsed_played_moves.length.even? ? "white" : "black"
    end

    # Check and apply timeout if time_control is set and expired
    def check_timeout!
      return false unless active? && time_control.present? && last_move_at.present?

      elapsed_ms = ((Time.current - last_move_at) * 1000).to_i
      turn = current_turn

      if turn == "white"
        remaining = (white_time_left || 0) - elapsed_ms
        if remaining <= 0
          update!(
            white_time_left: 0,
            status: "completed",
            termination_reason: "timeout",
            winner: "black"
          )
          return true
        end
      else
        remaining = (black_time_left || 0) - elapsed_ms
        if remaining <= 0
          update!(
            black_time_left: 0,
            status: "completed",
            termination_reason: "timeout",
            winner: "white"
          )
          return true
        end
      end
      false
    end

    # Move validator using the chess gem, relying on client FEN/PGN for saving state to avoid gem API limits
    def make_move!(san_move, client_fen, client_pgn, current_player_color)
      raise "A játszma nem aktív vagy már befejeződött!" unless active?

      if check_timeout!
        raise "Időtúllépés! A játszma véget ért."
      end

      require 'chess'
      
      game = ::Chess::Game.new
      
      # Replay existing moves to reach current state
      played_moves = parsed_played_moves
      played_moves.each do |m|
        game.move(m)
      end
      
      # Kiszámítjuk, kinek a köre jön a lépések száma alapján
      expected_turn = played_moves.length.even? ? "white" : "black"
      
      if expected_turn != current_player_color
        raise "Nem a te köröd jön!"
      end

      # Deduct time from thinking player if time_control is active
      if time_control.present? && last_move_at.present?
        elapsed_ms = ((Time.current - last_move_at) * 1000).to_i
        if current_player_color == "white"
          self.white_time_left = [self.white_time_left.to_i - elapsed_ms, 0].max
        else
          self.black_time_left = [self.black_time_left.to_i - elapsed_ms, 0].max
        end
      end
      
      # Validate the new move on the server
      game.move(san_move)
      
      # If no error was raised, the move is legal. Save client's provided strings.
      self.pgn = client_pgn
      self.fen = client_fen
      
      is_checkmate = san_move.to_s.include?('#') ||
                     client_pgn.to_s.match?(/(?:#|#\s*(?:1-0|0-1|\*))\s*$/) ||
                     (game.respond_to?(:checkmate?) && game.checkmate?) ||
                     (game.respond_to?(:in_checkmate?) && game.in_checkmate?) ||
                     (game.respond_to?(:over?) && game.over? && game.respond_to?(:status) && [:white_won, :black_won].include?(game.status))

      is_draw = client_pgn.to_s.match?(/(?:1\/2-1\/2|\bdraw\b|\bstalemate\b)\s*$/) ||
                (game.respond_to?(:stalemate?) && game.stalemate?) ||
                (game.respond_to?(:in_stalemate?) && game.in_stalemate?) ||
                (game.respond_to?(:over?) && game.over? && game.respond_to?(:status) && [:stalemate, :draw].include?(game.status))

      if is_checkmate
        self.status = "completed"
        self.termination_reason = "checkmate"
        self.winner = current_player_color
      elsif is_draw
        self.status = "completed"
        self.termination_reason = "stalemate"
        self.winner = "draw"
      end
      
      self.last_move_at = Time.current
      save!
    end
    
    def undo_move!
      return unless active?
      require 'chess'
      return if self.pgn.blank?
      
      played_moves = parsed_played_moves
      return if played_moves.empty?
      played_moves.pop
      
      game = ::Chess::Game.new
      played_moves.each { |m| game.move(m) }
      
      # Reconstruct PGN
      new_pgn = ""
      played_moves.each_slice(2).with_index do |pair, idx|
        new_pgn += "#{idx + 1}. #{pair[0]} "
        new_pgn += "#{pair[1]} " if pair[1]
      end
      
      self.pgn = new_pgn.strip
      
      # Attempt to get fen if the gem supports it, else use a placeholder and client will fix it.
      begin
        self.fen = game.respond_to?(:fen) ? game.fen : game.board.fen
      rescue
        self.fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
      end
      
      self.last_move_at = Time.current if time_control.present?
      save!
    end
  end
end
