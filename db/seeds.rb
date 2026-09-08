# ==============================================================================
# Bánk's Repository - Kezdeti Adatbázis Magok (Seeds)
# ==============================================================================
# Futtatás: bin/rails db:seed
# Létrehozza a platform tulajdonosának adminisztrátori fiókját és regisztrálja
# az első beépülő modult (Sakk / Chess App).
# ==============================================================================

puts "--- Bánk's Repository: Adatbázis magok betöltése ---"

# 1. Platform Rendszergazda (Admin) létrehozása / frissítése
initial_admin_pw = ENV["INITIAL_ADMIN_PASSWORD"].presence || (Rails.env.production? ? SecureRandom.hex(16) : "AdminPass123!")
admin = User.find_or_initialize_by(username: "bank")
admin.email = "bank@bankrepo.hu"
admin.password = initial_admin_pw if admin.new_record? || admin.password_digest.blank?
admin.role = "admin"
admin.status = "active"
admin.save!
puts "  [+] Adminisztrátori fiók kész: #{admin.username} (#{admin.email}) [Szerepkör: #{admin.role}]"
if ENV["INITIAL_ADMIN_PASSWORD"].blank? && Rails.env.production?
  puts "  [!] FIGYELEM (Production): Generált Admin jelszó: #{initial_admin_pw}"
end

# 2. Első Beépülő Modul: Sakk Alkalmazás (Chess Engine) regisztrálása
chess_app = AppDefinition.find_or_initialize_by(slug: "chess")
chess_app.name = "Sakk Mester (Chess Engine)"
chess_app.description = "Valós idejű többjátékos és AI sakk modul WebSocket támogatással."
chess_app.mount_path = "/chess"
chess_app.state = "active"
chess_app.icon_identifier = "chess"
chess_app.is_default_accessible = true
chess_app.requires_login = false # Vendégek is kipróbálhatják; az admin felületen bármikor átkapcsolható
chess_app.save!
puts "  [+] Modul regisztrálva: #{chess_app.name} (#{chess_app.mount_path}) [Státusz: #{chess_app.state}]"

# 3. Második Beépülő Modul: Grand Casino (Casino Engine) regisztrálása
casino_app = AppDefinition.find_or_initialize_by(slug: "casino")
casino_app.name = "Grand Casino"
casino_app.description = "Valós idejű többjátékos kaszinó szimulátor: Rulett, Baccarat és Blackjack asztalok, zsetonrendszer és ranglista."
casino_app.mount_path = "/casino"
casino_app.state = "active"
casino_app.icon_identifier = "casino"
casino_app.is_default_accessible = true
casino_app.requires_login = true # Kötelező belépés a zsetonszámlához
casino_app.save!
puts "  [+] Modul regisztrálva: #{casino_app.name} (#{casino_app.mount_path}) [Státusz: #{casino_app.state}]"

# Kezdő kaszinó asztalok létrehozása
roulette = Casino::Table.find_or_initialize_by(slug: "roulette-1")
roulette.name = "Arany Rulett Terem"
roulette.game_type = "roulette"
roulette.min_bet = 50
roulette.max_bet = 5000
roulette.state = "idle"
roulette.save!

baccarat = Casino::Table.find_or_initialize_by(slug: "baccarat-1")
baccarat.name = "Royal Baccarat Szalon"
baccarat.game_type = "baccarat"
baccarat.min_bet = 100
baccarat.max_bet = 10000
baccarat.state = "idle"
baccarat.save!

blackjack = Casino::Table.find_or_initialize_by(slug: "blackjack-1")
blackjack.name = "VIP Blackjack Asztal"
blackjack.game_type = "blackjack"
blackjack.min_bet = 50
blackjack.max_bet = 5000
blackjack.state = "idle"
blackjack.save!
puts "  [+] Kaszinó asztalok konfigurálva: Rulett, Baccarat, Blackjack"

# 4. Harmadik Beépülő Modul: Közösségi Rajzvászon (Canvas Engine) regisztrálása
canvas_app = AppDefinition.find_or_initialize_by(slug: "canvas")
canvas_app.name = "Közösségi Rajzvászon"
canvas_app.description = "Valós idejű több felhasználós rajzvászon WebSocket szinkronizációval, simított görbékkel és képexporttal."
canvas_app.mount_path = "/canvas"
canvas_app.state = "active"
canvas_app.icon_identifier = "canvas"
canvas_app.is_default_accessible = true
canvas_app.requires_login = false # Vendégek néző módban beléphetnek
canvas_app.save!
puts "  [+] Modul regisztrálva: #{canvas_app.name} (#{canvas_app.mount_path}) [Státusz: #{canvas_app.state}]"

# Kezdő rajztábla inicializálása
if defined?(Canvas::Board)
  Canvas::Board.default_board
  puts "  [+] Alapértelmezett közösségi rajztábla inicializálva"
end

# 5. Teszt / Vendég fiók létrehozása a fejlesztéshez
if Rails.env.development? || Rails.env.test? || ENV["SEED_DEMO_USER"] == "true"
  demo_user = User.find_or_initialize_by(username: "demo_user")
  demo_user.email = "demo@bankrepo.hu"
  demo_user.password = "DemoPass123!" if demo_user.new_record? || demo_user.password_digest.blank?
  demo_user.role = "user"
  demo_user.status = "active"
  demo_user.save!
  puts "  [+] Teszt fiók kész: #{demo_user.username} (#{demo_user.email})"
end

puts "--- Magok sikeresen betöltve! ---"

