# ==============================================================================
# Migráció: requires_login Mező Hozzáadása az AppDefinitions Táblához
# ==============================================================================
# Lehetővé teszi, hogy az adminisztrátor modulonként szabályozza:
# - requires_login = false esetén vendégek is beléphetnek a modulba (nincs kirúgás)
# - requires_login = true esetén a rendszer bejelentkezésre/regisztrációra irányít át
# ==============================================================================

class AddRequiresLoginToAppDefinitions < ActiveRecord::Migration[7.1]
  def change
    add_column :app_definitions, :requires_login, :boolean, default: false, null: false
    add_index  :app_definitions, :requires_login
  end
end

