class CreateChessMatches < ActiveRecord::Migration[7.1]
  def change
    create_table :chess_matches do |t|
      t.string :uuid, null: false, index: { unique: true }
      t.integer :white_user_id, index: true
      t.integer :black_user_id, index: true
      t.string :white_guest_id, index: true
      t.string :black_guest_id, index: true
      
      t.string :status, null: false, default: "pending", index: true
      t.string :winner
      t.string :termination_reason
      
      t.string :fen, null: false, default: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
      t.text :pgn
      
      t.integer :time_control
      t.integer :white_time_left
      t.integer :black_time_left
      t.datetime :last_move_at

      t.timestamps
    end
  end
end
