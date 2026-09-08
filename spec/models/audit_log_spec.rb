# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLog, type: :model do
  let(:actor) { User.create!(username: "auditor", email: "auditor@bankrepo.hu", password: "Password123!") }
  let(:target) { User.create!(username: "target", email: "target@bankrepo.hu", password: "Password123!") }
  let(:app_def) { AppDefinition.create!(slug: "demo", name: "Demo App", mount_path: "/demo") }

  describe ".log!" do
    it "creates an audit log entry for user target" do
      expect {
        AuditLog.log!(
          action: "user_unlocked",
          actor: actor,
          target: target,
          resource: target,
          metadata: { note: "test note" }
        )
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("user_unlocked")
      expect(log.actor_user_id).to eq(actor.id)
      expect(log.target_user_id).to eq(target.id)
      expect(log.resource_type).to eq("User")
      expect(log.resource_id).to eq(target.id)
      expect(log.metadata["note"]).to eq("test note")
    end

    it "safely logs non-user resources without setting target_user_id incorrectly" do
      expect {
        AuditLog.log!(
          action: "app_toggled",
          actor: actor,
          target: nil,
          resource: app_def,
          metadata: { new_state: "maintenance" }
        )
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("app_toggled")
      expect(log.target_user_id).to be_nil
      expect(log.resource_type).to eq("AppDefinition")
      expect(log.resource_id).to eq(app_def.id)
    end
  end
end
