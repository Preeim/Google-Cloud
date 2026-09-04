# ==============================================================================
# Migráció: Szerepkörök és Biztonsági Mezők Hozzáadása a Users Táblához
# ==============================================================================
# Bővíti a meglévő felhasználói rekordot az RBAC jogosultságokkal (role),
# a fiók életciklus státusszal (status) és a brute-force fiókzárolási
# mechanizmushoz szükséges időbélyegekkel.
# ==============================================================================

class AddRolesAndSecurityToUsers < ActiveRecord::Migration[7.1]
  def change
    change_table :users, bulk: true do |t|
      # Szerepkör: user, moderator, admin
      t.string   :role, default: "user", null: false
      
      # Fiók státusz: active, suspended, pending
      t.string   :status, default: "active", null: false
      
      # Brute-force védelem: hibás kísérletek száma és zárolás lejárati ideje
      t.integer  :failed_logins_count, default: 0, null: false
      t.datetime :locked_until
      
      # Munkamenet és jelszó biztonsági időbélyegek
      t.datetime :last_login_at
      t.datetime :password_changed_at
    end

    add_index :users, :role
    add_index :users, :status
  end
end

