# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppDefinition, type: :model do
  describe "validations and states" do
    it "creates active app definition with valid attributes" do
      app = AppDefinition.new(slug: "chess_test", name: "Chess Game", mount_path: "/chess_test")
      expect(app).to be_valid
      expect(app.state).to eq("active")
    end

    it "requires unique slug" do
      AppDefinition.create!(slug: "unique_app", name: "App 1", mount_path: "/app1")
      duplicate = AppDefinition.new(slug: "unique_app", name: "App 2", mount_path: "/app2")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to be_present
    end

    it "invalidates navigation cache after commit" do
      expect(Rails.cache).to receive(:delete).with("nav_apps_admin")
      expect(Rails.cache).to receive(:delete).with("nav_apps_user")

      AppDefinition.create!(slug: "cached_app", name: "Cached App", mount_path: "/cached")
    end
  end
end
