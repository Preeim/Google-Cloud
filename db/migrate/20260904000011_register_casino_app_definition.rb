class RegisterCasinoAppDefinition < ActiveRecord::Migration[7.1]
  def up
    # 1. Regisztráljuk a Casino modult az AppDefinition táblában
    app = AppDefinition.find_or_initialize_by(slug: "casino")
    app.name = "Grand Casino"
    app.description = "Valós idejű többjátékos kaszinó szimulátor: Rulett, Baccarat és Blackjack asztalok, zsetonrendszer és ranglista."
    app.mount_path = "/casino"
    app.state = "active"
    app.icon_identifier = "casino"
    app.is_default_accessible = true
    app.requires_login = true
    app.save!

    # 2. Kezdő kaszinó asztalok létrehozása
    if defined?(Casino::Table)
      Casino::Table.find_or_create_by!(slug: "roulette-1") do |t|
        t.name = "Arany Rulett Terem"
        t.game_type = "roulette"
        t.min_bet = 50
        t.max_bet = 5000
        t.state = "idle"
      end

      Casino::Table.find_or_create_by!(slug: "baccarat-1") do |t|
        t.name = "Royal Baccarat Szalon"
        t.game_type = "baccarat"
        t.min_bet = 100
        t.max_bet = 10000
        t.state = "idle"
      end

      Casino::Table.find_or_create_by!(slug: "blackjack-1") do |t|
        t.name = "VIP Blackjack Asztal"
        t.game_type = "blackjack"
        t.min_bet = 50
        t.max_bet = 5000
        t.state = "idle"
      end
    end
  end

  def down
    AppDefinition.find_by(slug: "casino")&.destroy
  end
end
