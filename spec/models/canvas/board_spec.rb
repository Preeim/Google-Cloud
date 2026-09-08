# frozen_string_literal: true

require "rails_helper"

RSpec.describe Canvas::Board, type: :model do
  describe ".default_board" do
    it "finds or creates the default main board" do
      board = Canvas::Board.default_board
      expect(board).to be_persisted
      expect(board.slug).to eq("main")
      expect(board.is_frozen).to be false
    end
  end

  describe "#toggle_freeze!" do
    it "toggles frozen state" do
      board = Canvas::Board.default_board
      expect(board.is_frozen?).to be false

      board.toggle_freeze!
      expect(board.reload.is_frozen?).to be true

      board.toggle_freeze!
      expect(board.reload.is_frozen?).to be false
    end
  end

  describe "#clear_canvas!" do
    it "deletes all strokes and resets strokes_count and snapshot_data" do
      board = Canvas::Board.default_board
      board.strokes.create!(tool: "brush", color: "#ffffff", width: 5, points_data: "[[10, 20]]")
      expect(board.strokes.count).to be >= 1

      board.clear_canvas!
      expect(board.strokes.count).to eq(0)
      expect(board.reload.strokes_count).to eq(0)
      expect(board.snapshot_data).to be_nil
    end
  end
end
