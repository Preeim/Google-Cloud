# frozen_string_literal: true

# ==============================================================================
# Migráció: Kaszinó Idegen Kulcsok & Kaszkádolt Törlés (ON DELETE CASCADE)
# ==============================================================================
# Biztosítja, hogy felhasználó, kaszinó profil vagy asztal törlése esetén
# a kapcsolódó rekordok (tétek, tranzakciók) automatikusan és tranzakció-
# biztosan törlődjenek adatbázis-szinten, elkerülve az árva rekordokat
# és a Foreign Key integritási kivételeket.
# ==============================================================================

class FixCasinoForeignKeysAndCascades < ActiveRecord::Migration[7.1]
  def change
    # 1. casino_profiles -> users
    if foreign_key_exists?(:casino_profiles, :users)
      remove_foreign_key :casino_profiles, :users
    end
    add_foreign_key :casino_profiles, :users, on_delete: :cascade

    # 2. casino_bets -> casino_profiles
    if foreign_key_exists?(:casino_bets, :casino_profiles)
      remove_foreign_key :casino_bets, :casino_profiles
    end
    add_foreign_key :casino_bets, :casino_profiles, on_delete: :cascade

    # 3. casino_bets -> casino_tables
    if foreign_key_exists?(:casino_bets, :casino_tables)
      remove_foreign_key :casino_bets, :casino_tables
    end
    add_foreign_key :casino_bets, :casino_tables, on_delete: :cascade

    # 4. casino_transactions -> casino_profiles
    if foreign_key_exists?(:casino_transactions, :casino_profiles)
      remove_foreign_key :casino_transactions, :casino_profiles
    end
    add_foreign_key :casino_transactions, :casino_profiles, on_delete: :cascade
  end
end

