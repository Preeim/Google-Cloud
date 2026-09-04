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

    # Move validator using the chess gem
    def make_move!(san_move)
      require 'chess'
      
      game = ::Chess::Game.new
      if self.pgn.present?
        game.load_pgn(self.pgn)
      end
      
      game.move(san_move)
      
      self.pgn = game.to_pgn
      self.fen = game.board.fen
      
      if game.board.checkmate?
        self.status = "completed"
        self.termination_reason = "checkmate"
        self.winner = game.turn == :white ? "black" : "white"
      elsif game.board.stalemate? || game.board.draw?
        self.status = "completed"
        self.termination_reason = "stalemate"
        self.winner = "draw"
      end
      
      self.last_move_at = Time.current
      save!
    end
    
    def undo_move!
      require 'chess'
      return if self.pgn.blank?
      
      game = ::Chess::Game.new
      game.load_pgn(self.pgn)
      
      # The `chess` gem doesn't always have a simple undo, we might have to replay all but the last move
      moves = game.moves
      moves.pop
      
      new_game = ::Chess::Game.new
      moves.each { |m| new_game.move(m) }
      
      self.pgn = new_game.to_pgn
      self.fen = new_game.board.fen
      save!
    end
  end
end
