# Kódbázis Működési és Kontextuskezelési Szabályzat (`context.md`)

## 1. Navigációs és Felderítési Protokoll (Reconnaissance First)
- TILOS a teljes projektet, könyvtárakat vagy felesleges modulokat beolvasni a kontextusba.
- Minden feladatot egy 2 fázisú folyamattal hajts végre:
  1. **Scout (Felderítő) fázis:** Azonosítsd a feladat pontos helyét a lenti Modultérkép, valamint szimbólumkeresés (LSP definition / references, grep) segítségével.
  2. **Editor (Végrehajtó) fázis:** Egyszerre kizárólag a szigorúan érintett 1–3 fájlt nyisd meg teljes terjedelmében.
- Ha egy hiba vagy új funkció a `chess` motort érinti, TILOS megnyitni a `casino`, `canvas` vagy a core app független fájljait.

## 2. Kódmódosítási Szabályok (Diff-based Editing)
- Soha ne generáld újra a teljes fájlokat; használj minimális, fókuszált patch-eket / Search-and-Replace blokkokat.
- Tartsd be a Rails konvenciókat (ActiveRecord minták, Service object-ek, ActionCable broadcast szabványok).

## 3. Determinisztikus Tesztelés és Hibajavítás
- Módosítás után kizárólag az érintett modul/motor tesztjeit futtasd (pl. `bundle exec rspec engines/chess/...`), ne a teljes tesztcsomagot.
- Hiba esetén a kapott hibaüzenet és stack trace alapján, célzottan végezz önjavítást (Self-Correction Loop).

## 4. Verziókezelés és Git Protokoll (Automated Git Push)
- Minden elvégzett és tesztelt feladat (task) lezárása után kötelező a változtatásokat commitolni és azonnal felpusholni a távoli Git tárolóba (`git add .`, `git commit -m "..."`, `git push`).
- A commit üzenetek legyenek tömörek és kövessék a konvenciókat.

## 5. Projekt Topológia és Modultérkép

### Core Alkalmazás (`app/`)
- **Fő modellek:** `User`, `ActiveSession`, `AppDefinition`, `UserAppPermission`, `AuditLog`, `ChatMessage`
- **Fő kontrollerek:**
  - Felhasználókezelés & Profil: `SessionsController`, `RegistrationsController`, `ProfilesController`
  - Chat & Műszerfal: `ChatMessagesController`, `DashboardController`, `PagesController`
  - Adminisztráció (`app/controllers/admin/`): `AppsController`, `UsersController`, `ServerMetricsController`, `AuditLogsController`, `DashboardController`
- **ActionCable csatornák:** `PresenceChannel`, `GlobalChatChannel`, `ServerMetricsChannel`
- **Szolgáltatások (Services):** `ServerMetricsService`, `AppBackupService`, `ProfileWidgets` (`AccountSecurityWidget`, `ActivityLogsWidget`, `CasinoStatsWidget`, `ChessStatsWidget`, `OverviewWidget`, `ProfileWidgetRegistry`)
- **Biztonság & Middleware:** `Security::RateLimiter` (`config/initializers/rate_limiter.rb`), `Rack::Attack`

---

### Rails Engines (`engines/`)

#### 1. Canvas Engine (`engines/canvas/`)
- **Felelősség:** Valós idejű közös rajztábla és jelenlét-kezelés.
- **Modellek:** `Canvas::Board`, `Canvas::Stroke`
- **Kontrollerek:** `Canvas::BoardsController` (`show`, `clear`, `toggle_freeze`, `save_snapshot`)
- **Csatorna:** `Canvas::BoardChannel` (`start_stroke`, `stream_points`, `finish_stroke`, `clear_board`, `toggle_freeze`, `presence`)

#### 2. Casino Engine (`engines/casino/`)
- **Felelősség:** Kaszinójátékok, virtuális egyenleg, tétek és asztalkezelés.
- **Modellek:** `Casino::Table`, `Casino::Profile`, `Casino::Bet`, `Casino::Transaction`
- **Játékmotorok & Szolgáltatások:** `Casino::BaccaratEngine`, `Casino::BlackjackEngine`, `Casino::RouletteEngine`, `Casino::TableManager`, `Casino::Scheduler`
- **Kontrollerek:** `Casino::LobbyController`, `Casino::TablesController` (`bet`, `action`, `spin`), `Casino::LeaderboardsController`
- **Adminisztráció:** `Casino::Admin::TablesController`, `Casino::Admin::UsersController`, `Casino::Admin::DashboardController`
- **Csatorna:** `Casino::TableChannel` (`place_bet`, `player_action`, `spin_wheel`)

#### 3. Chess Engine (`engines/chess/`)
- **Felelősség:** Valós idejű sakkpartik, lépésvalidáció, órakezelés és beállítások.
- **Modellek:** `Chess::Match` (`make_move!`, `undo_move!`, `check_timeout!`), `Chess::Setting`
- **Kontrollerek:** `Chess::MatchesController` (`create`, `join`, `cancel`, `destroy`), `Chess::DashboardController`
- **Adminisztráció:** `Chess::Admin::MatchesController`, `Chess::Admin::SettingsController`, `Chess::Admin::DashboardController`
- **Csatorna:** `Chess::MatchChannel` (`make_move`, `offer_draw`, `accept_draw`, `decline_draw`, `resign`, `request_takeback`, `answer_takeback`, `claim_timeout`)

