# frozen_string_literal: true

require "rails_helper"

RSpec.describe Canvas::Stroke, type: :model do
  let(:board) { Canvas::Board.default_board }
  let(:user) { User.create!(username: "artist", email: "artist@bankrepo.hu", password: "Password123!") }

  describe "creation and payload" do
    it "persists stroke and generates valid payload" do
      stroke = board.strokes.create!(
        user: user,
        tool: "brush",
        color: "#38bdf8",
        width: 6,
        points_data: '[[10, 20], [30, 40]]'
      )

      expect(stroke).to be_persisted
      payload = stroke.as_payload
      expect(payload[:tool]).to eq("brush")
      expect(payload[:color]).to eq("#38bdf8")
      expect(payload[:width]).to eq(6)
      expect(payload[:points]).to eq([[10, 20], [30, 40]])
      expect(payload[:user_name]).to eq("artist")
    end
  end
end
