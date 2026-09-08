# frozen_string_literal: true

# ==============================================================================
# Migráció: ChessMatches BigInt típuskorrekció, Idegen Kulcsok & Indexek
# ==============================================================================
# 1. Átalakítja a chess_matches tábla white_user_id és black_user_id mezőit
#    integer-ről (32-bit) bigint-re (64-bit), összhangba hozva a users.id típussal.
# 2. Adatbázis-szintű Foreign Key kényszereket hoz létre ON DELETE NULLIFY szabállyal.
# 3. Összetett indexet képez a casino_transactions táblán a gyors profil-lekérdezésekhez.
# ==============================================================================

class FixChessMatchesAndForeignKeys < ActiveRecord::Migration[7.1]
  def change
    # 1. Oszloptípus javítása bigint-re
    change_column :chess_matches, :white_user_id, :bigint
    change_column :chess_matches, :black_user_id, :bigint

    # 2. Idegen kulcsok (Foreign Keys) hozzáadása
    unless foreign_key_exists?(:chess_matches, :users, column: :white_user_id)
      add_foreign_key :chess_matches, :users, column: :white_user_id, on_delete: :nullify
    end

    unless foreign_key_exists?(:chess_matches, :users, column: :black_user_id)
      add_foreign_key :chess_matches, :users, column: :black_user_id, on_delete: :nullify
    end

    unless foreign_key_exists?(:audit_logs, :users, column: :actor_user_id)
      add_foreign_key :audit_logs, :users, column: :actor_user_id, on_delete: :nullify
    end

    unless foreign_key_exists?(:audit_logs, :users, column: :target_user_id)
      add_foreign_key :audit_logs, :users, column: :target_user_id, on_delete: :nullify
    end

    # 3. Összetett index a kaszinó tranzakciókra
    unless index_exists?(:casino_transactions, [:casino_profile_id, :created_at])
      add_index :casino_transactions, [:casino_profile_id, :created_at]
    end
  end
end
