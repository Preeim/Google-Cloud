class CreateCasinoTables < ActiveRecord::Migration[7.1]
  def change
    # 1. Kaszinó Felhasználói Profilok és Zsetonszámlák
    create_table :casino_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.bigint :chips, default: 10000, null: false
      t.integer :total_rounds_played, default: 0, null: false
      t.integer :total_won_rounds, default: 0, null: false

      t.timestamps
    end

    # 2. Pénzügyi és Zseton Tranzakciós Napló (Audit)
    create_table :casino_transactions do |t|
      t.references :casino_profile, null: false, foreign_key: true
      t.bigint :amount, null: false
      t.string :transaction_type, null: false # starting_grant, bet, payout, admin_adjustment, reset
      t.string :game_type, default: "system" # roulette, baccarat, blackjack, system
      t.bigint :balance_after, null: false
      t.text :metadata

      t.timestamps
    end

    # 3. Élő Multiplayer Kaszinó Asztalok
    create_table :casino_tables do |t|
      t.string :game_type, null: false # roulette, baccarat, blackjack
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.integer :min_bet, default: 50, null: false
      t.integer :max_bet, default: 5000, null: false
      t.string :state, default: "idle", null: false # idle, betting, resolving, finished, maintenance
      t.integer :round_number, default: 1, null: false
      t.text :state_data
      t.datetime :betting_closes_at

      t.timestamps
    end

    # 4. Leadott Tétek
    create_table :casino_bets do |t|
      t.references :casino_table, null: false, foreign_key: true
      t.references :casino_profile, null: false, foreign_key: true
      t.integer :round_number, null: false
      t.string :bet_type, null: false
      t.bigint :amount, null: false
      t.bigint :payout, default: 0, null: false
      t.string :status, default: "pending", null: false # pending, won, lost, push

      t.timestamps
    end

    add_index :casino_bets, [:casino_table_id, :round_number]
  end
end

