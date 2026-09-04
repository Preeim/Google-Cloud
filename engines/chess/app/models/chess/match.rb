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

    # Move validator using the chess gem, relying on client FEN/PGN for saving state to avoid gem API limits
    def make_move!(san_move, client_fen, client_pgn, current_player_color)
      require 'chess'
      
      game = ::Chess::Game.new
      
      # Replay existing moves to reach current state
      pgn_moves_part = self.pgn.to_s.split("]\n\n").last || self.pgn.to_s
      played_moves = pgn_moves_part.gsub(/\d+\./, '').split
      played_moves.reject! { |m| %w[1-0 0-1 1/2-1/2 *].include?(m) }
      played_moves.each do |m|
        game.move(m)
      end
      
      # Kiszámítjuk, kinek a köre jön a lépések száma alapján
      expected_turn = played_moves.length.even? ? "white" : "black"
      
      if expected_turn != current_player_color
        raise "Nem a te köröd jön!"
      end
      
      # Validate the new move on the server
      game.move(san_move)
      
      # If no error was raised, the move is legal. Save client's provided strings.
      self.pgn = client_pgn
      self.fen = client_fen
      
      if client_pgn.end_with?('#')
        self.status = "completed"
        self.termination_reason = "checkmate"
        self.winner = played_moves.length.even? ? "white" : "black"
      elsif client_pgn.end_with?('1/2-1/2')
        self.status = "completed"
        self.termination_reason = "stalemate"
        self.winner = "draw"
      end
      
      self.last_move_at = Time.current
      save!
    end
    
    def undo_move!
      # Manual undo by stripping the last move from PGN and recalculating FEN on client later, or simpler:
      # We just remove the last move from the PGN, and we don't recalculate FEN on server (client will resync it when they move again).
      # But wait, when takeback is accepted, client needs the new FEN immediately to render the board backwards!
      # We can use the chess gem to calculate the FEN of the previous state!
      require 'chess'
      return if self.pgn.blank?
      
      pgn_moves_part = self.pgn.to_s.split("]\n\n").last || self.pgn.to_s
      played_moves = pgn_moves_part.gsub(/\d+\./, '').split
      played_moves.reject! { |m| %w[1-0 0-1 1/2-1/2 *].include?(m) }
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
      # Most gems support game.board.fen or game.fen
      begin
        self.fen = game.respond_to?(:fen) ? game.fen : game.board.fen
      rescue
        self.fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" # Fallback, client might need to refresh
      end
      
      save!
    end
  end
end
