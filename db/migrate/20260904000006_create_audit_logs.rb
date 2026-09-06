# ==============================================================================
# Migráció: Biztonsági Audit Napló (AuditLogs) Tábla Létrehozása
# ==============================================================================
# Megmásíthatatlan biztonsági napló, amely minden adminisztrátori műveletet,
# szerepkör-módosítást, fiókzárolást és app-hozzáférés változást rögzít
# a platform megbízhatóságának és auditálhatóságának biztosítására.
# ==============================================================================

class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs do |t|
      t.bigint   :actor_user_id                       # Aki a műveletet végezte (admin/rendszer)
      t.bigint   :target_user_id                      # Akire a művelet hatott (opcionális)
      t.string   :action, null: false                 # pl. "user_locked", "role_changed", "app_toggled"
      t.string   :resource_type                       # pl. "User", "AppDefinition"
      t.bigint   :resource_id                         # Az érintett entitás azonosítója
      t.json     :metadata_payload                    # Részletes adatok (régi/új érték, kontextus)
      t.string   :ip_address                          # Kliens IP cím
      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :actor_user_id
    add_index :audit_logs, :target_user_id
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
  end
end

