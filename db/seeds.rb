# ==============================================================================
# Bánk's Repository - Kezdeti Adatbázis Magok (Seeds)
# ==============================================================================
# Futtatás: bin/rails db:seed
# Létrehozza a platform tulajdonosának adminisztrátori fiókját és regisztrálja
# az első beépülő modult (Sakk / Chess App).
# ==============================================================================

puts "--- Bánk's Repository: Adatbázis magok betöltése ---"

# 1. Platform Rendszergazda (Admin) létrehozása / frissítése
admin = User.find_or_initialize_by(username: "bank")
admin.email = "bank@bankrepo.hu"
admin.password = "AdminPass123!" # Telepítés után a felületen azonnal megváltoztatandó!
admin.role = "admin"
admin.status = "active"
admin.save!
puts "  [+] Adminisztrátori fiók kész: #{admin.username} (#{admin.email}) [Szerepkör: #{admin.role}]"

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

# 3. Teszt / Vendég fiók létrehozása a fejlesztéshez
demo_user = User.find_or_initialize_by(username: "demo_user")
demo_user.email = "demo@bankrepo.hu"
demo_user.password = "DemoPass123!"
demo_user.role = "user"
demo_user.status = "active"
demo_user.save!
puts "  [+] Teszt fiók kész: #{demo_user.username} (#{demo_user.email})"

puts "--- Magok sikeresen betöltve! ---"

