# Átfogó Független Rendszeraudit Jelentés (Blind Codebase Audit)
**Platform:** Bánk's Repository (GoogleCloudHub / Ruby on Rails 7.1)  
**Vizsgálat Dátuma:** 2026. szeptember 8.  
**Auditor:** Független Vezető Ruby on Rails Rendszerarchitekt és Biztonsági Szakértő  
**Megközelítés:** Zero-Trust, „Nulla előfeltételezéses” mélyelemzés (Blind Static & Architectural Audit)  

---

## 1. Vezetői Összefoglaló (Executive Summary)

A vizsgálat célja a **Bánk's Repository** teljes forráskódjának, adatmodelljének, konfigurációinak, moduláris motorjainak (Rails Engines: Sakk, Kaszinó, Rajzvászon), WebSocket kommunikációjának és üzemeltetési szkriptjeinek átvilágítása volt átadás-átvétel és éles üzem előtti minőségbiztosítás céljából.

### Főbb megállapítások:
- **Erősségek:**
  - A projekt modern Ruby on Rails 7.1 alapokra épül, fejlett ActiveModel és ActiveRecord mintákat alkalmaz (pl. `has_secure_password`, `ActiveSession` SHA-256 token hashing, csúszóablakos munkamenet-lejárat).
  - Magas szintű védelem a tipikus webes támadások ellen: `Rack::Attack` brute-force és throttling konfiguráció, Session Fixation elleni védelem (`reset_session`), szigorú felhasználónév/email normalizáció és honeypot botvédelem.
  - Tiszta elrendezésű moduláris motorok (`isolate_namespace`), tranzakciókezelés és pesszimista zárolás (`with_lock`) a kritikus pénzügyi/kaszinó műveleteknél.
  - Alapos, valós idejű telemetria és hardverfigyelés (`ServerMetricsService` Linux `/proc` alapokon).

- **Kritikus és Magas Kockázatok:**
  1. **Háttérszál többfolyamatos környezetben (`Casino::Scheduler`):** A nyers `Thread.new` szál a Puma szerver minden worker folyamatában külön elindul, ami versenyhelyzeteket, adatbázis-kapcsolat szivárgást és lock contention-t eredményez.
  2. **Üzemeltetési és folyamatvezérlési hiányosságok (`deploy.sh`):** A `nohup` és `kill -9` alapú szerverindítás Linux systemd és automatikus újraindítás nélkül instabilitást okozhat, különösen a szűkös erőforrású (1 GB RAM) GCP e2-micro környezetben.
  3. **Zombi session újraélesztési rés (`ApplicationController`):** A hibás vagy elavult tokenek pótlásánál a rendszer fiókstátusz-ellenőrzés nélkül hozhat létre új munkamenetet.
  4. **Adatbázis-szintű idegen kulcs hiányosságok:** A kaszinó táblákon hiányoznak a deklaratív `ON DELETE CASCADE` szabályok, ami közvetlen SQL törlések esetén integritási hibát vagy árva rekordokat okoz.
  5. **Architektúrális adósság:** Monolitikus nézetsablonok (több ezer soros inline JavaScript és CSS a `.html.erb` fájlokban).

---

## 2. Észrevételek Súlyossági Mátrixa (Severity Matrix)

| Kategória | 🔴 Kritikus | 🟠 Magas | 🟡 Közepes | 🟢 Alacsony | Összesen |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **1. Biztonság & Jogosultságkezelés** | 1 | 1 | 1 | 0 | **3** |
| **2. Kódminőség & Rails Konvenciók** | 0 | 0 | 2 | 2 | **4** |
| **3. Adatbázis & Skálázhatóság** | 1 | 2 | 1 | 0 | **4** |
| **4. Megbízhatóság, Tesztek & Hibák** | 0 | 0 | 0 | 2 | **2** |
| **5. Üzemeltetés & Konfiguráció** | 1 | 1 | 1 | 0 | **3** |
| **Összesen** | **3** | **4** | **5** | **4** | **16** |

---

## 3. Részletes Elemzés és Javítási Javaslatok

---

### 🔴 KRITIKUS / BLOCKER (Azonnali éles üzemi veszély)

#### [KRITIKUS-1] `Casino::Scheduler` nem felügyelt háttérszál Clustered Puma környezetben
- **Hivatkozás:** `engines/casino/lib/casino/scheduler.rb:12-24`, `engines/casino/lib/casino/engine.rb:16-23`
- **A probléma leírása:**  
  A `Casino::Scheduler.start!` metódus az alkalmazás inicializálásakor egy nyers Ruby szálat (`Thread.new`) indít, amely 2 másodpercenként futtat egy `tick!` ciklust az aktív asztalok kiértékelésére. Amennyiben a Puma szerver több workerrel fut (`WEB_CONCURRENCY > 1`), **minden egyes worker folyamat külön-külön elindítja a saját scheduler szálát**.  
  Ez azt jelenti, hogy 4 worker esetén 4 független szál verseng másodpercenként a zárolásokért és kapcsolatokért, ami:
  - Adatbázis lock contention-höz vezet.
  - Kimeríti a MySQL connection pool-t.
  - Worker újraindításkor vagy crash esetén a háttérszál azonnal elhalhat tranzakció közben.
- **Kockázat:** Adatbázis túlterhelés, duplikált körkiértékelési kísérletek, szál-szivárgás.
- **Javítási Javaslat:**  
  A feladatot át kell helyezni egy dedikált periodikus háttérfeladatba (pl. Rails 7.1+ Solid Queue, GoodJob vagy Sidekiq-cron), vagy az in-process futtatást egy atomi zárral (Leader Lock) kell védeni:

```ruby
# engines/casino/lib/casino/scheduler.rb JAVÍTVA
module Casino
  class Scheduler
    LOCK_KEY = "casino_scheduler_leader_lock"

    def self.tick!
      return unless ActiveRecord::Base.connection.table_exists?("casino_tables")

      # Csak az a worker futtatja, amelyik megszerzi az elosztott zárat
      acquired = Rails.cache.write(LOCK_KEY, Process.pid, expires_in: 5.seconds, unless_exist: true)
      return unless acquired

      begin
        tables = Casino::Table.active.where("betting_closes_at IS NOT NULL AND betting_closes_at <= ?", Time.current)
        tables.find_each do |table|
          if %w[betting player_turns].include?(table.state)
            Casino::TableManager.resolve_round(table)
          end
        end
      ensure
        # Zár fenntartása vagy feloldása
      end
    end
  end
end
```

---

#### [KRITIKUS-2] Éles üzemeltetés: `nohup rails server` folyamatvezérlés systemd / supervisor nélkül és OOM leállás
- **Hivatkozás:** `deploy.sh:83-108`
- **A probléma leírása:**  
  A `deploy.sh` a szervert háttérben futó `nohup bundle exec rails server -e production ... > log/server.log 2>&1 &` folyamatként indítja, a leállítást pedig manuális `pgrep` és `kill -9` parancsokkal végzi.  
  Egy GCP e2-micro virtuális gépen (1 GB fizikai RAM, 0.25 vCPU):
  - Ha a Puma folyamat memóriatúllépés (OOM Killer) vagy kezeletlen hiba miatt összeomlik, **a szerver végleg leáll**, és nincs semmi, ami újraindítsa.
  - A `log/server.log` fájl korlátlanul hízik (nincs logrotate integráció), ami napok alatt betöltheti a lemezt.
  - A `kill -9` drasztikusan megszakítja az éppen folyamatban lévő HTTP/WebSocket kapcsolatokat és tranzakciókat.
- **Kockázat:** Szolgáltatáskiesés, adatvesztés leállításkor, lemezterület megtelés.
- **Javítási Javaslat:**  
  Hozzon létre egy szabványos Linux `systemd` szolgáltatásfájlt a Pumához, és a `deploy.sh`-ban végezzen `systemctl reload` vagy `systemctl restart` hívást:

```ini
# /etc/systemd/system/banks-hub.service
[Unit]
Description=Bank's Repository Rails Application
After=network.target mysql.service

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/banks-hub
Environment=RAILS_ENV=production
ExecStart=/usr/local/bin/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=5
StandardOutput=append:/var/log/banks-hub/puma.log
StandardError=append:/var/log/banks-hub/puma.err.log

[Install]
WantedBy=multi-user.target
```

```bash
# deploy.sh JAVÍTVA (részlet)
echo "[5/5] Reloading Puma service via systemd..."
sudo systemctl restart banks-hub
sudo systemctl status banks-hub --no-pager
```

---

#### [KRITIKUS-3] `ApplicationController` Session helyreállítási rés (Re-authentication Bypass)
- **Hivatkozás:** `app/controllers/application_controller.rb:138-164`
- **A probléma leírása:**  
  Az `ApplicationController#current_user` logikájában:
  ```ruby
  elsif user_id.present?
    user = User.find_by(id: user_id)
    if user
      new_token, new_session = ActiveSession.create_from_request!(user, request)
      session[:session_token] = new_token
      @current_active_session = new_session
  ```
  Amennyiben a munkamenet sütiben szerepel a `session[:user_id]`, de a `session[:session_token]` hiányzik (pl. korábban törölték vagy érvénytelenítették), a rendszer **fiókállapot-ellenőrzés nélkül** azonnal legenerál egy új `ActiveSession`-t. Ha a felhasználót időközben felfüggesztették (`user.suspended?`) vagy zárolták (`user.locked?`), a rendszer automatikusan újra bejelentkezteti az unauthenticated kérések során.
- **Kockázat:** Felfüggesztett vagy kitiltott felhasználók visszatérése, jogosulatlan automatikus session-újragenerálás.
- **Javítási Javaslat:**  
  Kötelezővé kell tenni a felhasználó aktív státuszának ellenőrzését a munkamenet pótlása előtt, illetve a token hiánya esetén törölni kell a sütit (`reset_session`):

```ruby
# app/controllers/application_controller.rb JAVÍTVA
elsif user_id.present?
  user = User.find_by(id: user_id)
  if user && user.active? && !user.locked?
    begin
      new_token, new_session = ActiveSession.create_from_request!(user, request)
      session[:session_token] = new_token
      @current_active_session = new_session
    rescue StandardError => e
      Rails.logger.warn("[ApplicationController] ActiveSession automatikus pótlása sikertelen: #{e.message}")
    end
  else
    reset_session
    user = nil
  end
  user
end
```

---

### 🟠 MAGAS / HIGH (Biztonsági és stabilitási kockázatok)

#### [MAGAS-1] Hiányzó adatbázis-szintű kényszerek (Foreign Key Constraints) és árva rekordok kockázata
- **Hivatkozás:** `db/schema.rb:234-237`
- **A probléma leírása:**  
  A `schema.rb`-ben a kaszinó kapcsolatok idegen kulcsai így szerepelnek:
  ```ruby
  add_foreign_key "casino_bets", "casino_profiles"
  add_foreign_key "casino_bets", "casino_tables"
  add_foreign_key "casino_profiles", "users"
  add_foreign_key "casino_transactions", "casino_profiles"
  ```
  Ezeken a kulcsokon **nincs beállítva `on_delete: :cascade`** az adatbázis szintjén. Ha egy felhasználó, profil vagy asztal törlésre kerül közvetlen SQL-ből, vagy egy migráció során, az adatbázis `Cannot delete or update a parent row: a foreign key constraint fails` hibát dob, vagy törölt profilokhoz tartozó tranzakciók/tétek árván maradnak.
- **Kockázat:** Adatbázis-integritási hibák, adminisztrátori felhasználótörlés meghiúsulása.
- **Javítási Javaslat:**  
  Készítsen egy új migrációt az idegen kulcsok frissítésére:

```ruby
# db/migrate/20260908000003_fix_casino_foreign_keys.rb
class FixCasinoForeignKeys < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :casino_bets, :casino_profiles if foreign_key_exists?(:casino_bets, :casino_profiles)
    remove_foreign_key :casino_bets, :casino_tables if foreign_key_exists?(:casino_bets, :casino_tables)
    remove_foreign_key :casino_transactions, :casino_profiles if foreign_key_exists?(:casino_transactions, :casino_profiles)
    remove_foreign_key :casino_profiles, :users if foreign_key_exists?(:casino_profiles, :users)

    add_foreign_key :casino_profiles, :users, on_delete: :cascade
    add_foreign_key :casino_bets, :casino_profiles, on_delete: :cascade
    add_foreign_key :casino_bets, :casino_tables, on_delete: :cascade
    add_foreign_key :casino_transactions, :casino_profiles, on_delete: :cascade
  end
end
```

---

#### [MAGAS-2] Content Security Policy (CSP): `:unsafe_inline` és túl tág CDN tartományok
- **Hivatkozás:** `config/initializers/content_security_policy.rb:23-26`, `config/environments/production.rb:64`
- **A probléma leírása:**  
  A CSP konfiguráció engedélyezi az `:unsafe_inline` direktívát mind a scripteknél, mind a stílusoknál, valamint engedélyezi a nyilvános CDN-eket (`unpkg.com`, `cdnjs.cloudflare.com`, `jsdelivr.net`, `cdn.skypack.dev`).  
  Bár az alkalmazás jelenleg szűri a felhasználói bemenetet, az `:unsafe_inline` és a nyílt CDN-ek jelenléte semlegesíti a CSP elsődleges védelmi funkcióját: amennyiben egy jövőbeli felületen XSS sebezhetőség keletkezik, a támadó bármilyen tetszőleges kódot futtathat vagy betölthet a megengedett CDN-ekről.
- **Kockázat:** Gyengített XSS elleni védelem.
- **Javítási Javaslat:**  
  Használjon Rails Nonce generátort az inline scriptekhez (`<%= javascript_tag nonce: true %>`), és töltse le a külső vendor könyvtárakat helyi kiszolgálásra (`public/vendor/`):

```ruby
# config/initializers/content_security_policy.rb JAVÍTVA
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline # Stílusokhoz elfogadható
    policy.connect_src :self, :blob, "wss://bankrepo.hu", "ws://bankrepo.hu"
    policy.frame_ancestors :self
    policy.form_action :self
    policy.base_uri :self
  end

  # Automatikus nonce generálás scriptekhez
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)
end
```

---

#### [MAGAS-3] Hiányzó adatbázis-indexek gyakran szűrt és rendezett oszlopokon
- **Hivatkozás:** `db/schema.rb:45-58`, `db/schema.rb:101-109`, `db/schema.rb:111-127`
- **A probléma leírása:**  
  1. `casino_profiles`: A ranglista lekérdezés (`Profile.leaderboard`) a `chips DESC, total_won_rounds DESC` szerint rendez, azonban a táblán **csak a `user_id` oszlop van indexelve**. Ez növekvő felhasználói bázisnál full-table scant és lassú rendezést eredményez.
  2. `casino_tables`: A scheduler 2 másodpercenként futtatja a `where("betting_closes_at <= ?", Time.current)` lekérdezést, de a `betting_closes_at` oszlopon nincs index.
  3. `audit_logs`: A polimorf lekérdezésekhez (`where(resource_type: ..., resource_id: ...)`) hiányzik az összetett index.
- **Kockázat:** Lassuló adatbázis-lekérdezések, megnövekedett I/O terhelés.
- **Javítási Javaslat:**  
  Adja hozzá a hiányzó indexeket egy új migrációban:

```ruby
# db/migrate/20260908000004_add_missing_indexes.rb
class AddMissingIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :casino_profiles, [:chips, :total_won_rounds], name: "idx_casino_profiles_ranking"
    add_index :casino_tables, :betting_closes_at
    add_index :audit_logs, [:resource_type, :resource_id]
  end
end
```

---

#### [MAGAS-4] In-Memory ActionCable Async Adapter vs. Többfolyamatos Terhelés
- **Hivatkozás:** `config/cable.yml:15-19`
- **A probléma leírása:**  
  A konfiguráció alapértelmezésben:
  ```yaml
  production:
    adapter: <%= ENV.fetch("ACTION_CABLE_ADAPTER", "async") %>
  ```
  Az `async` adapter kizárólag egyetlen Ruby folyamat memóriájában képes üzeneteket továbbítani. Amennyiben a Puma szerver több worker folyamattal fut, vagy a terhelés növekedésével több szerverpéldány indul el, **a különböző folyamatokhoz csatlakozott felhasználók nem fogják megkapni egymás üzeneteit** (a chat, a sakk lépések és a kaszinó pörgetések elakadnak a folyamathatárokon).
- **Kockázat:** WebSocket üzenetszórás elakadása, inkonzisztens felhasználói felületek.
- **Javítási Javaslat:**  
  Éles környezetben állítsa be az `ACTION_CABLE_ADAPTER=redis` környezeti változót és a `REDIS_URL`-t, vagy dokumentálja kötelező feltételként a többfolyamatos üzemhez.

---

### 🟡 KÖZEPES / MEDIUM (Teljesítménybeli és architektúrális adósság)

#### [KÖZEPES-1] Monolitikus nézetsablonok és inline JavaScript/CSS túlsúly
- **Hivatkozás:**
  - `engines/chess/app/views/chess/matches/show.html.erb` (2 674 sor)
  - `engines/casino/app/views/casino/tables/show.html.erb` (1 380 sor)
  - `app/views/shared/_global_chat.html.erb` (881 sor)
  - `engines/canvas/app/views/canvas/boards/show.html.erb` (799 sor)
- **A probléma leírása:**  
  A nézetsablonok hatalmas mennyiségű beágyazott CSS stílust, HTML modálokat, beágyazott hangfájlokat és több száz soros kliensoldali JavaScript logikát tartalmaznak egyetlen fájlban.
  - A böngésző nem tudja gyorsítótárazni (cache-elni) a JavaScript és CSS fájlokat külön erőforrásként, így minden oldalbetöltés feleslegesen nagy HTML payloadot mozgat.
  - A kód nem tesztelhető JS egységtesztekkel (pl. Jest/Vitest), és nehezen olvasható/karbantartható.
- **Javítási Javaslat:**  
  Szervezze ki a stílusokat dedikált CSS fájlokba (`public/css/`), a JavaScript logikát pedig Stimulus kontrollerekbe vagy moduláris JS fájlokba (`public/js/`).

---

#### [KÖZEPES-2] Felesleges és inaktív konfigurációs kódok (Dead Code)
- **Hivatkozás:** `config/initializers/rate_limiter.rb:1-98`, `config/initializers/json_quirks_mode.rb:1-13`
- **A probléma leírása:**  
  A `rate_limiter.rb` fájl definiál egy 98 soros `Security::RateLimiter` middleware osztályt, de a fájl végén lévő megjegyzés szerint nincs regisztrálva a middleware láncban, mert a `Rack::Attack` helyettesíti. A `json_quirks_mode.rb` initializer pedig pusztán egy üres kommentfájl.
- **Javítási Javaslat:**  
  Törölje a nem használt inicializáló fájlokat, hogy ne zavarja meg a jövőbeli fejlesztőket és kódellenőrző eszközöket.

---

#### [KÖZEPES-3] Anti-Pattern: SQL Injection szűrés Regex feketelistával
- **Hivatkozás:** `app/controllers/sessions_controller.rb:9,23-26`, `app/controllers/registrations_controller.rb:12,24-28`
- **A probléma leírása:**  
  A `SessionsController` és a `RegistrationsController` az alábbi reguláris kifejezéssel próbálja szűrni a bemenetet:
  ```ruby
  SQL_INJECTION_PATTERN = /(--|\/\*|\*\/|;\s*$|'\s*or\s+|"\s*or\s+|'\s*and\s+|"\s*and\s+|union\s+select)/i
  ```
  A feketelistás reguláris kifejezésekkel történő SQL injection védelem ismert tervezési hiba (CWE-184):
  - Fals pozitív hibákat okozhat érvényes jelszavaknál vagy felhasználóneveknél.
  - Felesleges, mivel a Rails ActiveRecord paraméterezett lekérdezései (`User.find_by("LOWER(username) = ? OR LOWER(email) = ?", login_input, login_input)`) eleve 100%-os biztonságot nyújtanak.
- **Javítási Javaslat:**  
  Távolítsa el az ad-hoc regex szűrést, és bízza a védelmet a meglévő ActiveRecord paraméterezésre és a modell szintű whitelist formátumvalidációra (`format: { with: /\A[a-zA-Z0-9_]+\z/ }`).

---

#### [KÖZEPES-4] Kétirányú függőség a Core platform és az izolált Engine-ek között
- **Hivatkozás:** `app/models/user.rb:30`, `app/services/app_backup_service.rb:79-114`
- **A probléma leírása:**  
  Bár az Engine-ek (`chess`, `casino`, `canvas`) elméletileg izoláltak (`isolate_namespace`), a központi `User` modell közvetlen `has_one :casino_profile` kapcsolatot tartalmaz, és az `AppBackupService` hardcoded `case @app.slug` ágakkal menti az engine-ek tábláit.
- **Javítási Javaslat:**  
  Alakítson ki egy regisztrációs hook rendszert (hasonlóan a `ProfileWidgetRegistry`-hez), ahol minden engine maga regisztrálja a modelljeit és a mentési eljárását az `AppBackupService`-ben.

---

#### [KÖZEPES-5] Nagyméretű Base64 képadatok közvetlen adatbázis-tárolása (`Canvas::Board#snapshot_data`)
- **Hivatkozás:** `engines/canvas/app/models/canvas/board.rb:34-46`, `db/schema.rb:66`
- **A probléma leírása:**  
  A rajzvászon pillanatfelvételeit a rendszer Base64 formátumban (akár 3 MB adat) közvetlenül a MySQL tábla `snapshot_data: :longtext` oszlopába menti. Ez nagy adatbázis-rekordokat és memóriaterhelést eredményez.
- **Javítási Javaslat:**  
  Használjon `ActiveStorage`-ot vagy mentse a képeket közvetlenül a lemezre (`storage/canvas_snapshots/`), és az adatbázisban csak a fájl nevét vagy relatív elérési útját tárolja.

---

### 🟢 ALACSONY / LOW (Stilisztikai és refaktorálási javaslatok)

#### [ALACSONY-1] Nem használt Gem függőségek a Gemfile-ban
- **Hivatkozás:** `Gemfile:35,39,41`
- **A probléma leírása:**  
  A `Gemfile`-ban szerepel az `importmap-rails`, `turbo-rails` és `stimulus-rails`, miközben a `config/importmap.rb` fájl nem létezik, és az alkalmazás statikus vendor fájlokat használ.
- **Javítás:** Távolítsa el a nem használt gemeket a memóriafoglalás és indítási idő optimalizálása érdekében.

---

#### [ALACSONY-2] Kivétel-elnyelés (`rescue nil`) Audit naplózás során
- **Hivatkozás:** `engines/casino/app/controllers/casino/admin/users_controller.rb:30,46,62,81`
- **A probléma leírása:**  
  Az adminisztrátori műveleteknél az `AuditLog.log!(...) rescue nil` csendben elnyeli az adatbázis mentési hibákat anélkül, hogy legalább a szervernaplóba beírná.
- **Javítás:** Cserélje le `rescue StandardError => e; Rails.logger.error(...)` hívásra.

---

#### [ALACSONY-3] Hiányzó Channel és Controller integrációs tesztek
- **Hivatkozás:** `spec/` mappa
- **A probléma leírása:**  
  Bár az alapvető modellek teszteltek, hiányoznak a Channel specifikációk (`GlobalChatChannel`, `Casino::TableChannel`, `Canvas::BoardChannel`, `Chess::MatchChannel`) és a `ChatMessagesController`, `ProfilesController` tesztjei.
- **Javítás:** RSpec tesztcsomag kiegészítése a hiányzó kontrollerekre és WebSocket csatornákra.

---

#### [ALACSONY-4] Kódduplikáció a JavaScript segédfüggvényekben
- **Hivatkozás:** `_global_chat.html.erb`, `canvas/boards/show.html.erb`, `casino/tables/show.html.erb`
- **A probléma leírása:**  
  Az `escapeHtml(str)` és az időformázó függvények minden sablonban külön meg vannak írva.
- **Javítás:** Helyezze át a közös segédfüggvényeket egy központi `public/js/utils.js` fájlba.

---

## 4. Objektív Rendszerértékelés (Readiness Score)

| Szempont | Pontszám (1-10) | Értékelés |
| :--- | :---: | :--- |
| **Biztonság (Security)** | **8.5 / 10** | Erős autentikáció, SHA-256 session lenyomatok, Rack::Attack és CSP jelenlét. Kisebb javítás szükséges a session pótlásnál és a CSP szigorításánál. |
| **Kódminőség & MVC (Code Quality)** | **7.0 / 10** | Tiszta modellek és concern-ök, de a monolitikus, több ezer soros ERB nézetsablonok rontják az összképet. |
| **Adatbázis & Integritás (Database)** | **7.5 / 10** | Jól strukturált séma, de hiányzó kaszinó ranglista indexek és hiányzó `ON DELETE CASCADE` idegen kulcsok. |
| **Megbízhatóság & Tranzakciók (Reliability)** | **8.0 / 10** | Pesszimista zárolások (`with_lock`) a pénzügyi műveleteknél, tranzakcióbiztos törlések. A háttérszál (`Scheduler`) javítandó. |
| **Üzemeltetés & Infrastruktúra (DevOps)** | **6.5 / 10** | A GCP e2-micro VM monitorozása kiváló, de a `deploy.sh` nohup/kill folyamatvezérlése cserére szorul systemd-re. |
| **ÖSSZESÍTETT ÉLES ÜZEMI KÉSZÜLTSÉG** | **7.5 / 10** | **Élesítésre alkalmas a 3 kritikus javítás elvégzése után.** |

---

## 5. Prioritási Teendők és Menetrend (Action Roadmap)

### 🚀 1. Fázis: Azonnali Teendők (Launch Blockers - 1-2 nap)
1. **`Casino::Scheduler` felügyelete:** Elosztott zár (Leader Lock) bevezetése vagy Solid Queue / cron feladattá alakítás.
2. **`deploy.sh` átállítása systemd szolgáltatásra:** Megbízható Puma service automatikus újraindítással és logrotate-tel.
3. **`ApplicationController` session pótlás javítása:** Fiókállapot (`active?`, `!locked?`) ellenőrzése a fallback ágon.
4. **Kaszinó idegen kulcsok frissítése:** Migráció futtatása `on_delete: :cascade` hozzáadására.

### 🔧 2. Fázis: Stabilitás és Teljesítmény (1. Hét)
5. **Adatbázis indexek pótlása:** `casino_profiles` (ranglista), `casino_tables` (időzítő), `audit_logs` (polimorf).
6. **Inaktív kódok takarítása:** `rate_limiter.rb` és felesleges Gemek eltávolítása.
7. **Kivételkezelés javítása:** `rescue nil` cseréje strukturált naplózásra.

### 💎 3. Fázis: Architektúrális Refaktorálás (2-3. Hét)
8. **Nézetsablonok modularizálása:** Több ezer soros inline JS és CSS kiszervezése Stimulus kontrollerekbe és külön asset fájlokba.
9. **Tesztlefedettség bővítése:** ActionCable és hiányzó controller specifikációk megírása.
