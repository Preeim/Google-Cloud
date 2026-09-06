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

    # Helpers
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

    # Ellenőrzi, hogy az adott felhasználó/vendég a szoba létrehozója-e
    def creator?(user = nil, guest_id = nil)
      if user.present?
        (white_user_id.present? && white_user_id == user.id) || (black_user_id.present? && black_user_id == user.id)
      elsif guest_id.present?
        (white_guest_id.present? && white_guest_id.to_s == guest_id.to_s) || (black_guest_id.present? && black_guest_id.to_s == guest_id.to_s)
      else
        false
      end
    end

    # Ellenőrzi, hogy a felhasználó vagy vendég résztvevő-e a meccsben
    def participant?(user = nil, guest_id = nil)
      creator?(user, guest_id)
    end

    # Megkeresi a felhasználó vagy vendég jelenleg nyitott/aktív játszmáját
    def self.open_match_for(user = nil, guest_id = nil)
      return nil if user.nil? && guest_id.nil?

      where(status: ["pending", "active"]).where(
        "white_user_id = :uid OR black_user_id = :uid OR white_guest_id = :gid OR black_guest_id = :gid",
        uid: user&.id, gid: guest_id
      ).order(created_at: :desc).first
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
      
      # Validate the new move on the server with defensive fallback for SAN quirks
      begin
        game.move(san_move)
      rescue => e
        # If the gem is strict about trailing #, +, or = notation:
        clean_san = san_move.to_s.sub(/[\+\#]$/, '')
        if clean_san != san_move
          begin
            game.move(clean_san)
          rescue
            raise e
          end
        else
          raise e
        end
      end
      
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
    
    def undo_move!(requested_by_color = nil)
      return unless active?
      require 'chess'
      return if self.pgn.blank?
      
      played_moves = parsed_played_moves
      return if played_moves.empty?

      # If the player who asked for takeback is the one whose turn it currently is,
      # it means they want to take back their OWN previous move (which was followed by the opponent's move).
      # Therefore, both moves (2 plies) must be popped.
      if requested_by_color.present? && requested_by_color.to_s == current_turn
        if played_moves.length >= 2
          played_moves.pop
          played_moves.pop
        else
          played_moves.pop
        end
      else
        played_moves.pop
      end
      
      game = ::Chess::Game.new
      played_moves.each { |m| game.move(m) rescue nil }
      
      # Reconstruct PGN
      new_pgn = ""
      played_moves.each_slice(2).with_index do |pair, idx|
        new_pgn += "#{idx + 1}. #{pair[0]} "
        new_pgn += "#{pair[1]} " if pair[1]
      end
      
      self.pgn = new_pgn.strip
      
      # Megbízható FEN generálás a visszalépés utáni állapothoz
      if played_moves.empty?
        self.fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
      else
        calculated_fen = nil
        begin
          if game.board.respond_to?(:to_fen)
            calculated_fen = game.board.to_fen
          elsif game.respond_to?(:to_fen)
            calculated_fen = game.to_fen
          elsif game.respond_to?(:fen)
            calculated_fen = game.fen
          elsif game.board.respond_to?(:fen)
            calculated_fen = game.board.fen
          end
        rescue => e
          logger.warn("FEN kinyerési hiba a sakk gem-ből: #{e.message}") rescue nil
        end

        # Ha a gem adott FEN-t, azt mentjük; ha nem, akkor a meglévő vagy számított FEN-t használjuk
        self.fen = calculated_fen if calculated_fen.present?
      end
      
      self.last_move_at = Time.current if time_control.present?
      save!
    end
  end
end
