# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_09_08_000002) do
  create_table "active_sessions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "session_token_digest", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_activity_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_active_sessions_on_expires_at"
    t.index ["session_token_digest"], name: "index_active_sessions_on_session_token_digest", unique: true
    t.index ["user_id", "last_activity_at"], name: "index_active_sessions_on_user_id_and_last_activity_at"
    t.index ["user_id"], name: "index_active_sessions_on_user_id"
  end

  create_table "app_definitions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.text "description"
    t.string "mount_path", null: false
    t.string "state", default: "active", null: false
    t.string "icon_identifier"
    t.boolean "is_default_accessible", default: true, null: false
    t.boolean "requires_login", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["requires_login"], name: "index_app_definitions_on_requires_login"
    t.index ["slug"], name: "index_app_definitions_on_slug", unique: true
    t.index ["state"], name: "index_app_definitions_on_state"
  end

  create_table "audit_logs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "actor_user_id"
    t.bigint "target_user_id"
    t.string "action", null: false
    t.string "resource_type"
    t.bigint "resource_id"
    t.json "metadata_payload"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["actor_user_id"], name: "index_audit_logs_on_actor_user_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["target_user_id"], name: "index_audit_logs_on_target_user_id"
  end

  create_table "canvas_boards", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", default: "Közösségi Rajzvászon", null: false
    t.string "slug", default: "main", null: false
    t.boolean "is_frozen", default: false, null: false
    t.integer "width", default: 1600, null: false
    t.integer "height", default: 900, null: false
    t.text "snapshot_data", size: :long
    t.integer "strokes_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_canvas_boards_on_slug", unique: true
  end

  create_table "canvas_strokes", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "board_id", null: false
    t.bigint "user_id"
    t.string "tool", default: "brush", null: false
    t.string "color", default: "#38bdf8", null: false
    t.integer "width", default: 4, null: false
    t.text "points_data", size: :medium, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["board_id"], name: "index_canvas_strokes_on_board_id"
    t.index ["user_id"], name: "index_canvas_strokes_on_user_id"
  end

  create_table "casino_bets", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "casino_table_id", null: false
    t.bigint "casino_profile_id", null: false
    t.integer "round_number", null: false
    t.string "bet_type", null: false
    t.bigint "amount", null: false
    t.bigint "payout", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["casino_profile_id"], name: "index_casino_bets_on_casino_profile_id"
    t.index ["casino_table_id", "round_number"], name: "index_casino_bets_on_casino_table_id_and_round_number"
    t.index ["casino_table_id"], name: "index_casino_bets_on_casino_table_id"
  end

  create_table "casino_profiles", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "chips", default: 10000, null: false
    t.integer "total_rounds_played", default: 0, null: false
    t.integer "total_won_rounds", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_casino_profiles_on_user_id", unique: true
  end

  create_table "casino_tables", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "game_type", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "min_bet", default: 50, null: false
    t.integer "max_bet", default: 5000, null: false
    t.string "state", default: "idle", null: false
    t.integer "round_number", default: 1, null: false
    t.text "state_data"
    t.datetime "betting_closes_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_type", "state"], name: "index_casino_tables_on_game_type_and_state"
    t.index ["game_type"], name: "index_casino_tables_on_game_type"
    t.index ["slug"], name: "index_casino_tables_on_slug", unique: true
    t.index ["state"], name: "index_casino_tables_on_state"
  end

  create_table "casino_transactions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "casino_profile_id", null: false
    t.bigint "amount", null: false
    t.string "transaction_type", null: false
    t.string "game_type", default: "system"
    t.bigint "balance_after", null: false
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["casino_profile_id", "created_at"], name: "index_casino_transactions_on_casino_profile_id_and_created_at"
    t.index ["casino_profile_id"], name: "index_casino_transactions_on_casino_profile_id"
  end

  create_table "chat_messages", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at", "deleted_at"], name: "index_chat_messages_on_created_at_and_deleted_at"
    t.index ["deleted_at"], name: "index_chat_messages_on_deleted_at"
    t.index ["user_id"], name: "index_chat_messages_on_user_id"
  end

  create_table "chess_matches", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "uuid", null: false
    t.bigint "white_user_id"
    t.bigint "black_user_id"
    t.string "white_guest_id"
    t.string "black_guest_id"
    t.string "status", default: "pending", null: false
    t.string "winner"
    t.string "termination_reason"
    t.string "fen", default: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", null: false
    t.text "pgn"
    t.integer "time_control"
    t.integer "white_time_left"
    t.integer "black_time_left"
    t.datetime "last_move_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["black_guest_id"], name: "index_chess_matches_on_black_guest_id"
    t.index ["black_user_id"], name: "index_chess_matches_on_black_user_id"
    t.index ["status"], name: "index_chess_matches_on_status"
    t.index ["uuid"], name: "index_chess_matches_on_uuid", unique: true
    t.index ["white_guest_id"], name: "index_chess_matches_on_white_guest_id"
    t.index ["white_user_id"], name: "index_chess_matches_on_white_user_id"
  end

  create_table "chess_settings", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.boolean "allow_guests", default: true, null: false
    t.integer "default_time_control", default: 600, null: false
    t.string "available_time_controls", default: "0,180,300,600,900,1800", null: false
    t.boolean "allow_takeback", default: true, null: false
    t.boolean "allow_draw_offer", default: true, null: false
    t.integer "auto_abort_minutes", default: 30, null: false
    t.boolean "single_challenge_limit", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_app_permissions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "app_definition_id", null: false
    t.string "access_level", default: "standard", null: false
    t.bigint "granted_by_user_id"
    t.datetime "granted_at", null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_level"], name: "index_user_app_permissions_on_access_level"
    t.index ["app_definition_id"], name: "index_user_app_permissions_on_app_definition_id"
    t.index ["user_id", "app_definition_id"], name: "idx_user_app_perm_unique", unique: true
    t.index ["user_id"], name: "index_user_app_permissions_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "username", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "user", null: false
    t.string "status", default: "active", null: false
    t.integer "failed_logins_count", default: 0, null: false
    t.datetime "locked_until"
    t.datetime "last_login_at"
    t.datetime "password_changed_at"
    t.datetime "last_seen_at"
    t.string "display_name", limit: 50
    t.text "bio"
    t.string "avatar_color", limit: 20, default: "#38bdf8", null: false
    t.string "custom_status", limit: 120
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_seen_at"], name: "index_users_on_last_seen_at"
    t.index ["role"], name: "index_users_on_role"
    t.index ["status"], name: "index_users_on_status"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_sessions", "users", on_delete: :cascade
  add_foreign_key "audit_logs", "users", column: "actor_user_id", on_delete: :nullify
  add_foreign_key "audit_logs", "users", column: "target_user_id", on_delete: :nullify
  add_foreign_key "canvas_strokes", "canvas_boards", column: "board_id", on_delete: :cascade
  add_foreign_key "canvas_strokes", "users", on_delete: :nullify
  add_foreign_key "casino_bets", "casino_profiles"
  add_foreign_key "casino_bets", "casino_tables"
  add_foreign_key "casino_profiles", "users"
  add_foreign_key "casino_transactions", "casino_profiles"
  add_foreign_key "chat_messages", "users", on_delete: :cascade
  add_foreign_key "chess_matches", "users", column: "black_user_id", on_delete: :nullify
  add_foreign_key "chess_matches", "users", column: "white_user_id", on_delete: :nullify
  add_foreign_key "user_app_permissions", "app_definitions", on_delete: :cascade
  add_foreign_key "user_app_permissions", "users", on_delete: :cascade
end
