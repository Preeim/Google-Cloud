# frozen_string_literal: true

# ==============================================================================
# Migráció: Teljesítmény-optimalizáló Adatbázis Indexek Hozzáadása
# ==============================================================================
# 1. casino_profiles: összetett index (chips, total_won_rounds) a ranglista
#    lekérdezések (Profile.leaderboard) gyorsításához.
# 2. casino_tables: index a betting_closes_at oszlopon a periodikus körkiértékelő
#    (Casino::Scheduler.tick!) full-table scan-jének megszüntetéséhez.
# 3. audit_logs: összetett polimorf index (resource_type, resource_id) a
#    erőforrás-alapú naplólekérdezések gyorsításához.
# ==============================================================================

class AddMissingPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # 1. Kaszinó ranglista összetett index
    unless index_exists?(:casino_profiles, [:chips, :total_won_rounds], name: "idx_casino_profiles_ranking")
      add_index :casino_profiles, [:chips, :total_won_rounds], name: "idx_casino_profiles_ranking"
    end

    # 2. Kaszinó asztalok időzített szűrésének indexe
    unless index_exists?(:casino_tables, :betting_closes_at)
      add_index :casino_tables, :betting_closes_at
    end

    # 3. Audit log polimorf erőforrás index
    unless index_exists?(:audit_logs, [:resource_type, :resource_id], name: "idx_audit_logs_resource")
      add_index :audit_logs, [:resource_type, :resource_id], name: "idx_audit_logs_resource"
    end
  end
end

