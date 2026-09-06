# ==============================================================================
# Migráció: Felhasználói App Jogosultságok (UserAppPermissions) Tábla
# ==============================================================================
# Granuláris hozzáférési mátrix az egyes felhasználók és alkalmazások között.
# Szabályozza a jogosultsági szintet (standard, béta-tesztelő, menedzser),
# támogatja a határozott idejű vagy egyedi engedélyezést.
# ==============================================================================

class CreateUserAppPermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :user_app_permissions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :app_definition, null: false, foreign_key: { on_delete: :cascade }
      t.string     :access_level, default: "standard", null: false # standard, beta_tester, manager, revoked
      t.bigint     :granted_by_user_id
      t.datetime   :granted_at, null: false
      t.datetime   :expires_at

      t.timestamps
    end

    add_index :user_app_permissions, [:user_id, :app_definition_id], unique: true, name: "idx_user_app_perm_unique"
    add_index :user_app_permissions, :access_level
  end
end

