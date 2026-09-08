# Független, Nulla Előfeltételezéses (Blind Audit) Rendszerelemzési Jelentés
**Projekt:** Bánk's Repository (Google Cloud Hub)  
**Vizsgált technológiai stack:** Ruby on Rails 7.1.4, Ruby 3.2+, MySQL 8, Puma, Action Cable (WebSockets), In-App Rails Engines (Canvas, Casino, Chess)  
**Audit Típusa:** Teljes körű független biztonsági, kódminőségi, adatbázis, megbízhatósági és üzemeltetési felülvizsgálat  
**Dátum:** 2026. szeptember 8.  

---

## Vezetői Összefoglaló (Executive Summary)

A vizsgálat során a teljes kódbázis statikus forráskódját, konfigurációs állományait, adatbázis-migrációit, izolált moduljait (Rails Engines), WebSocket csatornáit, nézeteit és deployment szkriptjeit elemeztük, külső szakértői megközelítéssel, feltételezve, hogy a rendszer élesítés előtt áll.

A projekt felépítése ambiciózus és modern: a modularizáció (Rails Engines: Sakk, Kaszinó, Rajzvászon), a valós idejű WebSocket kommunikáció (Action Cable), a testreszabható profilrendszer, a dedikált Admin felület és a telemetriai monitorozás kiváló funkcionális alapot nyújtanak. Ugyanakkor az átadás-átvétel és a biztonságos éles üzemeltetés előtt **több kritikus biztonsági rés, hitelesítési anomália, N+1 lekérdezési adósság és súlyos tesztlefedettségi hiányosság** szorul azonnali elhárításra.

### Észrevételek Összesítése Súlyosság Szerint
- 🔴 **[KRITIKUS / BLOCKER]: 3 db** (Azonnali éles üzemi és biztonsági veszély)
- 🟠 **[MAGAS / HIGH]: 6 db** (Súlyos biztonsági, adatintegritási vagy stabilitási kockázat)
- 🟡 **[KÖZEPES / MEDIUM]: 6 db** (Teljesítménybeli, architektúrális és skálázhatósági adósság)
- 🟢 **[ALACSONY / LOW]: 4 db** (Stilisztikai, karbantarthatósági és pipeline javaslat)

---

## Részletes Észrevételek és Javítási Útmutató

---

### 1. 🔴 KRITIKUS / BLOCKER ÉSZREVÉTELEK

---

#### 1.1. Hardcoded Nyilvános `SECRET_KEY_BASE` a Verziókövetett Kódban
- **Érintett fájlok:**
  - [`config/boot.rb:15`](file:///f:/Workplace/Google-Cloud/config/boot.rb#L15)
  - [`config/environments/production.rb:19`](file:///f:/Workplace/Google-Cloud/config/environments/production.rb#L19)
- **Kategória:** Biztonság / Autentikáció / RCE kockázat
- **A probléma leírása:**
  A rendszer konfigurációjában mind a boot folyamatban, mind az éles környezeti beállításokban egy statikus, publikusan a git repóban tárolt 128 karakteres hexa kulcs szerepel tartalékként:
  `"a4b2c8e1f0d3e5a7b9c6d4e2f1a0b8c7d5e3f2a1b9c0d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7"`.
  Amennyiben az `ENV["SECRET_KEY_BASE"]` környezeti változó hiányzik vagy hibásan van átadva, a Rails élesben ezzel a nyilvános kulccsal inicializálja az üzenettitkosítást és a cookie-kezelést. Ezzel egy támadó tetszőlegesen aláírt session cookie-t gyárthat, tetszőleges felhasználó (beleértve a rendszergazdát) nevében bejelentkezhet, és a MessageEncryptor / ActiveSupport deserialization mechanizmusokon keresztül akár távoli kódfuttatást (RCE) is elérhet.
- **Javítási kód:**
  ```ruby
  # config/environments/production.rb
  # Töröljük a hardcoded stringet; kötelezővé tesszük a környezeti változót:
  effective_secret = ENV["SECRET_KEY_BASE"].to_s.strip
  if effective_secret.blank?
    raise "KRITIKUS HIBA: A SECRET_KEY_BASE környezeti változó nincs beállítva éles környezetben!"
  end
  config.secret_key_base = effective_secret
  ```

---

#### 1.2. ActionCable Guest Identity Impersonation (Hitelesítési Megkerülés a Sakk Modulban)
- **Érintett fájl:** [`engines/chess/app/channels/chess/match_channel.rb:201-203`](file:///f:/Workplace/Google-Cloud/engines/chess/app/channels/chess/match_channel.rb#L201-L203)
- **Kategória:** Biztonság / Jogosultságkezelés / IDOR
- **A probléma leírása:**
  A `Chess::MatchChannel` a játékos színének (`current_player_color`) meghatározásakor az `effective_guest_id` segédmetódust hívja meg:
  ```ruby
  def effective_guest_id
    params[:guest_id].presence || guest_id.to_s
  end
  ```
  A `params[:guest_id]` a feliratkozó kliens által tetszőlegesen megadott WebSocket paraméter, ami felülbírálja a titkosított session cookie-ból ellenőrzött `guest_id`-t. Így egy támadó a WebSocket kézfogáskor átadott `{ guest_id: "áldozat_guest_id" }` paraméterrel tetszőleges vendégjátékos nevében léphet, visszalépést kérhet vagy feladhatja a játszmát.
- **Javítási kód:**
  ```ruby
  # engines/chess/app/channels/chess/match_channel.rb
  def effective_guest_id
    # Kizárólag a kapcsolat létesítésekor ellenőrzött session guest_id fogadható el!
    guest_id.to_s
  end
  ```

---

#### 1.3. Kritikus Tesztlefedettségi Hiány (Mindössze 3 db Modell Teszt a Teljes Alkalmazásra)
- **Érintett mappa:** [`spec/`](file:///f:/Workplace/Google-Cloud/spec)
- **Kategória:** Megbízhatóság / Tesztelés / Élesítési Blocker
- **A probléma leírása:**
  A teljes alkalmazásban mindössze három darab izolált modell teszt létezik (`user_spec.rb`, `casino/profile_spec.rb`, `chess/match_spec.rb`). Teljesen hiányoznak:
  - Request / Controller specifikációk (Autentikáció, RBAC admin jogosultságok, profil módosítások, brute-force védelem).
  - Kaszinó játékmotor szabálytesztek (Rulett, Baccarat és Blackjack kifizetési szorzók, push állapotok, fedezetlevonás).
  - Rajzvászon (Canvas) és Globális Chat WebSocket integritási tesztek.
  - Sakk játszma érvényesítési és időtúllépési (timeout) folyamattesztek.
  Ilyen állapotban a rendszer átadása vagy refaktorálása beláthatatlan regressziós kockázatot rejt.
- **Javítási kód:**
  Létre kell hozni a dedikált request és service teszteket:
  ```ruby
  # spec/requests/sessions_spec.rb
  require "rails_helper"

  RSpec.describe "Sessions", type: :request do
    let!(:user) { User.create!(username: "tester", email: "tester@bankrepo.hu", password: "Password123!") }

    it "blocks login when account is locked" do
      user.lock_access!
      post "/login", params: { login: user.username, password: "Password123!" }
      expect(response).to have_http_status(:locked)
    end
  end
  ```

---

### 2. 🟠 MAGAS / HIGH ÉSZREVÉTELEK

---

#### 2.1. DOM-alapú Stored XSS a Közösségi Rajzvászon Jelenléti Sávjában (Canvas Presence)
- **Érintett fájl:** [`engines/canvas/app/views/canvas/boards/show.html.erb:668-676`](file:///f:/Workplace/Google-Cloud/engines/canvas/app/views/canvas/boards/show.html.erb#L668-L676)
- **Kategória:** Biztonság / Cross-Site Scripting (XSS)
- **A probléma leírása:**
  Az `updatePresenceUI` JavaScript függvény a WebSocketen érkező felhasználói adatokat közvetlenül a DOM `innerHTML` tulajdonságába ágyazza:
  ```javascript
  pill.innerHTML = `
    <span class="user-pill-avatar" style="background: ${u.avatar_color || '#38bdf8'};">${u.avatar_initials || 'U'}</span>
    <span style="font-weight: 600; color: var(--text-main);">${u.username}</span>
    ...
  `;
  ```
  A `Canvas::BoardChannel` a `current_user.effective_name`-et küldi át `username`-ként. Egy felhasználó olyan megjelenített nevet (`display_name`) állíthat be a profiljában (pl. `<img src=x onerror=alert(document.cookie)>`), amely a rajzvászon megnyitásakor azonnal lefut minden csatlakozott látogató és adminisztrátor böngészőjében.
- **Javítási kód:**
  ```javascript
  // engines/canvas/app/views/canvas/boards/show.html.erb
  function escapeHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  const safeUsername = escapeHtml(u.username);
  const safeInitials = escapeHtml(u.avatar_initials || 'U');
  const safeColor = escapeHtml(u.avatar_color || '#38bdf8');

  pill.innerHTML = `
    <span class="user-pill-avatar" style="background: ${safeColor};">${safeInitials}</span>
    <span style="font-weight: 600; color: var(--text-main);">${safeUsername}</span>
    ${u.can_draw ? '<span class="user-pill-draw-dot" title="Rajzoló"></span>' : '<span class="user-pill-view-dot" title="Néző"></span>'}
  `;
  ```

---

#### 2.2. Típuseltérési Hiba (AssociationTypeMismatch) és Néma Hibaelnyelés az Admin Audit Naplózásban
- **Érintett fájl:** [`engines/casino/app/controllers/casino/admin/tables_controller.rb:18-22, 54-58`](file:///f:/Workplace/Google-Cloud/engines/casino/app/controllers/casino/admin/tables_controller.rb#L18-L22)
- **Kategória:** Adatintegritás / Auditálhatóság / Silent Exception
- **A probléma leírása:**
  Az asztal állapotának módosításakor (`toggle`) és a körök visszaállításakor (`reset_round`) az alábbi kód fut le:
  ```ruby
  ::AuditLog.log!(
    action: "casino_table_state_toggled",
    actor: current_user,
    target: @table,     # <-- HIBA: @table nem User entitás!
    resource: @table,
    ...
  ) rescue nil          # <-- HIBA: Némán elnyeli a kivételt!
  ```
  Az `AuditLog` modellben `belongs_to :target_user, class_name: "User"` szerepel, amelyre idegen kulcs kényszer is mutat a `users` táblára. A `target: @table` átadásakor az ActiveRecord `AssociationTypeMismatch` hibát dob, amit a sor végi `rescue nil` elnyel. Emiatt az adminisztrátori kaszinó műveletekről **soha egyetlen bejegyzés sem jön létre az audit naplóban**.
- **Javítási kód:**
  ```ruby
  # engines/casino/app/controllers/casino/admin/tables_controller.rb
  ::AuditLog.log!(
    action: "casino_table_state_toggled",
    actor: current_user,
    target: nil,          # target_user kizárólag User entitás lehet
    resource: @table,     # Az érintett entitás átadása resource-ként
    request: request,
    metadata: { old_state: old_state, new_state: new_state, table_name: @table.name }
  )
  ```

---

#### 2.3. Nem Biztonságos Állapotmódosító GET Végpontok (Logout és Sakk Csatlakozás)
- **Érintett fájlok:**
  - [`config/routes.rb:19`](file:///f:/Workplace/Google-Cloud/config/routes.rb#L19)
  - [`engines/chess/config/routes.rb:13`](file:///f:/Workplace/Google-Cloud/engines/chess/config/routes.rb#L13)
  - [`engines/chess/app/controllers/chess/matches_controller.rb:22-25`](file:///f:/Workplace/Google-Cloud/engines/chess/app/controllers/chess/matches_controller.rb#L22-L25)
- **Kategória:** Biztonság / CSRF / REST konvenciók
- **A probléma leírása:**
  1. A `get "/logout", to: "sessions#destroy"` útvonal lehetővé teszi a felhasználók akaratlan kiléptetését egyszerű képi beágyazással (`<img src="/logout">`).
  2. A `get :join` és a `MatchesController#show`-ban lévő `if params[:join] == "true"` blokk GET kérésre módosítja az adatbázist (átállítja a meccs státuszát aktívra és lefoglalja a színt). Ez sérti a HTTP idempotenciát, és keresőrobotok vagy böngésző-előretöltők (link prefetching) véletlenül elindíthatnak meccseket.
- **Javítási kód:**
  ```ruby
  # config/routes.rb
  # Töröljük a get "/logout" sort, kizárólag a DELETE marad:
  delete "/logout", to: "sessions#destroy", as: :logout

  # engines/chess/config/routes.rb
  # Töröljük a get :join sort, csak POST engedélyezett:
  resources :matches, only: [:index, :show, :create, :destroy] do
    member do
      post :join
      post :cancel
    end
  end
  ```

---

#### 2.4. Memória Kimerülési és DoS Kockázat a Modul Biztonsági Mentésben (AppBackupService)
- **Érintett fájl:** [`app/services/app_backup_service.rb:84-96`](file:///f:/Workplace/Google-Cloud/app/services/app_backup_service.rb#L84-L96)
- **Kategória:** Teljesítmény / Skálázhatóság / Memóriaszivárgás
- **A probléma leírása:**
  A modulok adminisztrátori kikapcsolásakor automatikusan lefutó `AppBackupService` a `Casino::Bet.all.as_json`, `Casino::Transaction.all.as_json`, `Canvas::Stroke.all.as_json` hívásokkal a teljes adatbázistáblát egyszerre tölti be a Ruby folyamat memóriájába egyetlen hatalmas tömbként. Nagyobb forgalom után (pl. 500 ezer fogadás vagy vonalmozdulat) ez azonnali Out-Of-Memory (OOM) leállást idéz elő a GCP e2-micro VM-en.
- **Javítási kód:**
  ```ruby
  # app/services/app_backup_service.rb
  # Használjunk kötegelt beolvasást vagy korlátozzuk az archívum méretét:
  when "casino"
    if defined?(Casino::Profile)
      profiles = Casino::Profile.includes(:user).limit(1000).map { |p| p.as_json.merge("username" => p.user.username) }
      recent_bets = defined?(Casino::Bet) ? Casino::Bet.order(id: :desc).limit(5000).as_json : []
      recent_txs = defined?(Casino::Transaction) ? Casino::Transaction.order(id: :desc).limit(5000).as_json : []
      payload[:data][:profiles] = profiles
      payload[:data][:bets] = recent_bets
      payload[:data][:transactions] = recent_txs
    end
  ```

---

#### 2.5. Rate Limiting és Méretvalidáció Hiánya a Canvas WebSocket Vonalmentésben
- **Érintett fájl:** [`engines/canvas/app/channels/canvas/board_channel.rb:67-90`](file:///f:/Workplace/Google-Cloud/engines/canvas/app/channels/canvas/board_channel.rb#L67-L90)
- **Kategória:** Biztonság / DoS / Adatbázis túlterhelés
- **A probléma leírása:**
  A `BoardChannel#finish_stroke` és `stream_points` akciókon nincs kérésszám-korlátozás (rate limit), és a `data["points"]` tömb hosszára sem létezik felső korlát. Egy rosszindulatú kliens másodpercenként több ezer `finish_stroke` üzenetet küldhet, vagy egyetlen vonásban több százezer koordinátát továbbíthat, ami túlterheli a MySQL adatbázist és megtölti a lemezt.
- **Javítási kód:**
  ```ruby
  # engines/canvas/app/channels/canvas/board_channel.rb
  def finish_stroke(data)
    return unless can_draw?(@board)
    if rate_limited?
      transmit({ type: "error", message: "Túl gyors rajzolási művelet!" })
      return
    end

    points = data["points"]
    return if points.blank? || !points.is_a?(Array) || points.size > 2000 # Max 2000 pont / vonal

    stroke = @board.strokes.create(
      user: current_user,
      tool: %w[brush eraser].include?(data["tool"]) ? data["tool"] : "brush",
      color: data["color"].to_s[0..20],
      width: data["width"].to_i.clamp(1, 40),
      points_data: points.to_json
    )
    ...
  end
  ```

---

#### 2.6. Hardcoded Alapértelmezett Adatbázis és Seed Jelszavak
- **Érintett fájlok:**
  - [`config/database.yml:6`](file:///f:/Workplace/Google-Cloud/config/database.yml#L6)
  - [`db/seeds.rb:14`](file:///f:/Workplace/Google-Cloud/db/seeds.rb#L14)
- **Kategória:** Biztonság / Titokkezelés
- **A probléma leírása:**
  1. A `database.yml`-ben a fallback jelszó: `"password123"`.
  2. A `db/seeds.rb`-ben az alapértelmezett admin jelszó: `"AdminPass123!"`.
  Ha az éles szerveren a környezeti változók nélkül fut le a seedelés vagy az adatbázis-kapcsolódás, a rendszer publikusan ismert alapértelmezett jelszavakkal üzemel.
- **Javítási kód:**
  ```ruby
  # db/seeds.rb
  initial_admin_pass = ENV["INITIAL_ADMIN_PASSWORD"].presence || SecureRandom.hex(12)
  admin.password = initial_admin_pass
  admin.save!
  puts "  [+] Adminisztrátori fiók inicializálva! Jelszó: #{initial_admin_pass}"
  ```

---

### 3. 🟡 KÖZEPES / MEDIUM ÉSZREVÉTELEK

---

#### 3.1. Súlyos N+1 Lekérdezések a Sakk Adminisztrációban
- **Érintett fájl:** [`engines/chess/app/controllers/chess/admin/matches_controller.rb:18`](file:///f:/Workplace/Google-Cloud/engines/chess/app/controllers/chess/admin/matches_controller.rb#L18)
- **Kategória:** Teljesítmény / Adatbázis
- **A probléma leírása:**
  Az adminisztrátori mérkőzéslista lekérdezése `@matches = @matches.order(created_at: :desc).limit(100)` módon történik `includes(:white_player, :black_player)` nélkül. A nézetben minden egyes mérkőzésnél lefut a játékosok felhasználónevének lekérdezése, ami 100 meccs esetén **200 felesleges SQL lekérdezést** generál egyetlen kérés alatt.
- **Javítási kód:**
  ```ruby
  # engines/chess/app/controllers/chess/admin/matches_controller.rb
  @matches = Match.includes(:white_player, :black_player)
  ```

---

#### 3.2. Adatbázis Lekérdezés Közvetlenül a Fő Alkalmazás Layout Sablonjában
- **Érintett fájl:** [`app/views/layouts/application.html.erb:70`](file:///f:/Workplace/Google-Cloud/app/views/layouts/application.html.erb#L70)
- **Kategória:** Kódminőség / MVC architektúra
- **A probléma leírása:**
  A layout nézetben minden egyes HTTP kérésnél lefut egy közvetlen adatbázis-lekérdezés:
  `AppDefinition.available_to_users.order(:name)`.
  Ez megsérti az MVC elveket és felesleges adatbázis-terhelést ró a szerverre.
- **Javítási kód:**
  Az alkalmazások listáját a `ApplicationController`-ben kell előkészíteni vagy a `Rails.cache`-ben tárolni:
  ```ruby
  # app/controllers/application_controller.rb
  def nav_apps
    @nav_apps ||= Rails.cache.fetch("nav_apps_list", expires_in: 10.minutes) do
      AppDefinition.available_to_users.order(:name).to_a
    end
  end
  ```

---

#### 3.3. In-Memory Osztályváltozó Használata Kaszinó Játékos Jelenléthez (`@@presence`)
- **Érintett fájl:** [`engines/casino/app/services/casino/table_manager.rb:7-38`](file:///f:/Workplace/Google-Cloud/engines/casino/app/services/casino/table_manager.rb#L7-L38)
- **Kategória:** Architektúra / Skálázhatóság
- **A probléma leírása:**
  A `TableManager` a játékosok online jelenlétét a Ruby folyamat memóriájában (`@@presence = {}`) tárolja. Több Puma worker (cluster mode) vagy több szerver esetén a munkamenetek nem látják egymás jelenlétét, így a `has_online_players?` hibásan `false` értéket adhat, és leállíthatja az asztalt.
- **Javítási kód:**
  A jelenléti listát a `Rails.cache` (Redis) rétegben kell tárolni:
  ```ruby
  def self.register_presence(table_id, user_id)
    key = "casino_table_presence:#{table_id}"
    users = Rails.cache.read(key) || {}
    users[user_id] = Time.current.to_i
    Rails.cache.write(key, users, expires_in: 5.minutes)
  end
  ```

---

#### 3.4. Hiányzó `db/schema.rb` és Lapozás Hiánya az Admin Felületen
- **Érintett fájlok:** [`db/`](file:///f:/Workplace/Google-Cloud/db), [`app/controllers/admin/users_controller.rb:13`](file:///f:/Workplace/Google-Cloud/app/controllers/admin/users_controller.rb#L13)
- **Kategória:** Adatbázis / Karbantarthatóság
- **A probléma leírása:**
  1. A projekt verziókövetéséből hiányzik a `db/schema.rb`, ami megnehezíti a tiszta adatbázis-állapot áttekintését és a tesztadatbázis inicializálását.
  2. Az `Admin::UsersController#index` minden felhasználót egyszerre tölt be (`User.order(created_at: :desc)`), lapozás nélkül.
- **Javítási kód:**
  Futtatni kell a `bin/rails db:schema:dump` parancsot, és be kell vezetni egyszerű lapozást (pl. `limit(25).offset(...)` vagy Pagy gem).

---

#### 3.5. Túlkapó SQL-Injection Regex a Jelszavak Ellenőrzésére
- **Érintett fájlok:**
  - [`app/controllers/sessions_controller.rb:9, 21`](file:///f:/Workplace/Google-Cloud/app/controllers/sessions_controller.rb#L9)
  - [`app/controllers/registrations_controller.rb:12, 24`](file:///f:/Workplace/Google-Cloud/app/controllers/registrations_controller.rb#L12)
- **Kategória:** Biztonság / Felhasználói élmény
- **A probléma leírása:**
  A bejelentkezési és regisztrációs űrlap egyedi reguláris kifejezéssel ellenőrzi a jelszavakat (`SQL_INJECTION_PATTERN`). Mivel a Rails paraméterezett lekérdezései (`User.find_by("LOWER(username) = ? ...", ...)`) natívan és biztonságosan kezelik az összes bemenetet, ez a regex teljesen felesleges, viszont hibásan letiltja az olyan biztonságos jelszavakat, amelyekben kötőjelduplázás (`--`) vagy idézőjelek szerepelnek.
- **Javítási kód:**
  Távolítsuk el a jelszó mezők egyedi regex vizsgálatát; bízzuk a védelmet a Rails beépített paraméter-kötéseire.

---

#### 3.6. Hiányzó `config.hosts` Védelem Élesben (DNS Rebinding Kockázat)
- **Érintett fájl:** [`config/environments/production.rb:40`](file:///f:/Workplace/Google-Cloud/config/environments/production.rb#L40)
- **Kategória:** Biztonság / Hálózati konfiguráció
- **A probléma leírása:**
  A `config.hosts.clear` direktíva kikapcsolja a Rails beépített Host Authorization middleware-jét, védtelenné téve a szervert a DNS Rebinding támadásokkal szemben.
- **Javítási kód:**
  ```ruby
  # config/environments/production.rb
  config.hosts = [
    "bankrepo.hu",
    "www.bankrepo.hu",
    "127.0.0.1",
    "localhost"
  ]
  ```

---

### 4. 🟢 ALACSONY / LOW ÉSZREVÉTELEK

---

#### 4.1. Felesleges (Halott) Függőségek a Gemfile-ban
- **Érintett fájl:** [`Gemfile:35, 38, 41`](file:///f:/Workplace/Google-Cloud/Gemfile#L35)
- **Leírás:** A `Gemfile`-ban szerepel az `importmap-rails`, `turbo-rails` és `stimulus-rails` gem, miközben az alkalmazásban nincs `config/importmap.rb`, nincs `app/javascript/` mappa, és a JavaScript fájlok közvetlenül a `public/vendor/` könyvtárból töltődnek be.
- **Javaslat:** Tisztítsuk meg a `Gemfile`-t a felesleges gemektől a gyorsabb bundle telepítés és kisebb memórialábnyom érdekében.

#### 4.2. Hiányzó CI/CD Munkafolyamat (Automated Testing & Security Scanning)
- **Érintett mappa:** `.github/workflows/` (nem létezik)
- **Leírás:** Nincs beállítva GitHub Actions CI pipeline, amely minden módosításkor automatikusan lefuttatná a biztonsági statikus analízist (`brakeman`), a kódstílus-ellenőrzést (`rubocop`) és a teszteket (`rspec`).
- **Javaslat:** Hozzunk létre egy `.github/workflows/ci.yml` konfigurációt.

#### 4.3. `ServerMetricsService` Lemezterület Shell Hívás (`df -Pk /`)
- **Érintett fájl:** [`app/services/server_metrics_service.rb:347`](file:///f:/Workplace/Google-Cloud/app/services/server_metrics_service.rb#L347)
- **Leírás:** A lemezterület ellenőrzése `` `df -Pk / 2>/dev/null` `` subshell hívással történik. Bár nem tartalmaz injektálható paramétert, Ruby szinten a folyamat-elágaztatás (fork/exec) felesleges erőforrást emészt fel másodpercenkénti hívásoknál.
- **Javaslat:** Használjunk `Sys::Filesystem` gemet vagy `/proc/mounts` közvetlen beolvasást.

#### 4.4. Deployment Script Folyamatkezelés Modernizálása (Systemd vs nohup)
- **Érintett fájl:** [`deploy.sh:81`](file:///f:/Workplace/Google-Cloud/deploy.sh#L81)
- **Leírás:** A `deploy.sh` a Puma szervert `nohup bundle exec rails server ... &` parancssal indítja háttérben. Ha a folyamat váratlanul leáll, nincs automatikus újraindulás.
- **Javaslat:** Állítsunk be egy dedikált Systemd egységfájlt (`bankrepo.service`) a Puma menedzselésére.

---

## Objektív Készültségi Értékelés

| Kategória | Pontszám (1–10) | Szöveges Értékelés |
| :--- | :---: | :--- |
| **1. Biztonság & Hitelesítés** | **6 / 10** | Erős alapok (bcrypt, Rack::Attack, CSP, session digest), de a hardcoded fallback titok és az ActionCable guest impersonation azonnali javítást igényel. |
| **2. Kódminőség & Architektúra** | **7 / 10** | Tiszta moduláris Rails Engine felépítés, jól elkülönített funkciók, de a nézetekben túl sok inline JS és közvetlen DB lekérdezés található. |
| **3. Adatbázis & Teljesítmény** | **6 / 10** | Megfelelő migrációs szerkezet és indexelés, de jelen vannak N+1 lekérdezések és memóriaveszélyes unbuffered lekérdezések a mentésben. |
| **4. Megbízhatóság & Tesztek** | **3 / 10** | **Kritikus hiányosság.** A mindössze 3 darab modell teszt nem nyújt biztonsági garanciát élesítés előtt. |
| **5. Üzemeltetés & Deployment** | **7 / 10** | Működőképes deploy szkript és Nginx biztonsági fejlécek, de hiányzik a Systemd integráció és a CI/CD pipeline. |
| **ÖSSZESÍTETT ÉRETTSÉGI SZINT** | **5.8 / 10** | **Feltételesen alkalmas:** A 3 db kritikus és a 6 db magas kockázatú hiba elhárítása és a tesztek pótlása kötelező az éles indulás előtt. |

---

## Prioritási Teendők és Megvalósítási Ütemterv (Roadmap)

### 1. Fázis: Azonnali Biztonsági Javítások (Hotfix - 24 órán belül)
1. **[KRITIKUS]** A hardcoded `SECRET_KEY_BASE` törlése a `config/boot.rb` és `config/environments/production.rb` fájlokból.
2. **[KRITIKUS]** A `Chess::MatchChannel` `effective_guest_id` metódus javítása (külső `params[:guest_id]` kizárása).
3. **[MAGAS]** A Canvas `updatePresenceUI` és a kapcsolódó WebSocket nézetek HTML-escaping javítása az XSS elhárítására.
4. **[MAGAS]** Az `engines/casino/app/controllers/casino/admin/tables_controller.rb` audit log hívásainak javítása (`target: nil, resource: @table`).
5. **[MAGAS]** A `get "/logout"` és `get :join` állapotmódosító GET útvonalak megszüntetése.

### 2. Fázis: Stabilitás & Teljesítmény Optimalizáció (1 héten belül)
1. **[MAGAS]** Az `AppBackupService` export logikájának átírása kötegelt (`find_each`) feldolgozásra.
2. **[MAGAS]** Rate limit és méretkorlát bevezetése a Canvas `finish_stroke` csatornaműveletre.
3. **[KÖZEPES]** Eager loading (`includes(:white_player, :black_player)`) bevezetése a sakk adminban az N+1 lekérdezések megszüntetésére.
4. **[KÖZEPES]** A layoutból kivezetni a közvetlen adatbázis lekérdezést (`AppDefinition.available_to_users`).
5. **[KÖZEPES]** `db:schema:dump` futtatása és a `db/schema.rb` commitolása.

### 3. Fázis: Tesztlefedettség & Üzemeltetés (Élesítés előtt)
1. **[KRITIKUS]** Átfogó RSpec tesztcsomag kiépítése (Authentikáció, RBAC, Kaszinó egyenlegtranzakciók, Sakk időzítés).
2. **[KÖZEPES]** Redis alapú tároló konfigurálása a kaszinó jelenléthez (`TableManager`) és az Action Cable-höz.
3. **[ALACSONY]** GitHub Actions CI pipeline beállítása (`brakeman`, `rubocop`, `rspec`).
4. **[ALACSONY]** A `deploy.sh` átállítása Systemd alapú Puma szolgáltatásmenedzsmentre.

