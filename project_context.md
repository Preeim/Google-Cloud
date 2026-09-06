# Project Context & Architecture

This document serves as the master reference for future developments on this project. It contains the essential details about the tech stack, infrastructure, deployment workflow, and crucial technical limitations.

## 🏗 Infrastructure
- **Hosting:** Google Cloud Platform (GCP) Compute Engine.
  - **Machine Type:** E2-micro (0.25 vCPU, 2 GiB RAM).
  - **Region:** `europe-west1` (Belgium).
  - **OS:** Ubuntu 22.04 LTS.
- **Domain & DNS:** `bankrepo.hu` (purchased via Rackhost). A Records for `@` and `www` point to the GCP static IP.
- **Web Server:** Nginx.
  - Acts as a reverse proxy, terminating SSL (via Let's Encrypt / Certbot).
  - Forwards standard HTTP/HTTPS traffic to the Puma application server running on `127.0.0.1:3000`.
  - Forwards WebSocket traffic specifically configured under the `/cable` location block.

## 🛠 Tech Stack
- **Ruby:** 3.3.0 (Compiled from source on the server, managed via rbenv).
- **Ruby on Rails:** 7.1.4.
- **Database:** MySQL 8+.
- **WebSockets:** Action Cable.

## ⚠️ Critical Quirks & Limitations
The server runs Ruby 3.3.0, which has a known syntax parser bug regarding "anonymous keyword rest parameters" when gems use modern `**` block forwarding. Because of this, certain dependencies must remain tightly pinned until the server's Ruby version is upgraded:
- **Rails is pinned to `~> 7.1.4`:** Upgrading to Rails 8.0+ causes crashes in `actionview`.
- **`connection_pool` is pinned to `~> 2.4.1`:** Versions 3.0+ will crash the server on startup.
- **`redis` is pinned to `~> 5.0`.**

*Note for AI/Developers: When adding or updating gems, always verify compatibility with Ruby 3.3.0. If the server crashes on startup after an update, check the Puma logs (`cat log/production.log` or `journalctl -u puma_bankrepo`) for `SyntaxError`.*

## 🚀 Deployment Workflow
1. **Local Development:** Write code locally on Windows and test.
   - *Windows Git tip:* `core.fscache` and `core.preloadindex` are enabled. If `.git/index` ever requires resetting, use the `git fixindex` alias.
2. **Push to GitHub:** Commit and push changes to `https://github.com/Preeim/Google-Cloud` (`main` branch).
3. **Deploy:** 
   - SSH into the Google Cloud VM.
   - Run `./deploy.sh` from the `~/Google-Cloud` directory.
   - The script automatically: pulls from git, installs bundle dependencies, runs database migrations, and restarts the Puma daemon.

## 📦 Current Features & Architecture
- **Authentication:** Custom authentication system using `has_secure_password` (bcrypt). Includes `User` model, `RegistrationsController`, and `SessionsController`.
- **Testing Console:** A general testing area (`/test/index`) used to validate Action Cable WebSocket connections, including ping/pong latency tests and a broadcast echo room.
- **Frontend styling:** Custom Tailwind-style utility classes integrated into the main application layout.
- **Chess Module (`engines/chess`):** Full multiplayer chess engine with live Action Cable WebSocket sync, timers, spectating, and PGN recording.
- **Casino Simulator (`engines/casino`):** Modular casino platform featuring European Roulette, Punto Banco Baccarat, and multiplayer Blackjack with live hit/stand controls, 10,000 starting chips, audit transactions (`casino_transactions`), and admin controls.
  - Tables: `casino_profiles`, `casino_tables`, `casino_bets`, `casino_transactions`.
- **Server Monitoring & System Health (`/bank-admin/server_metrics`, `/admin/system`):** Real-time hardware and network metrics dashboard with ActionCable WebSocket broadcasting, Linux `/proc` telemetry, non-blocking service object, Chart.js time-series graphs, and local Windows fallback.
- **Collaborative Real-time Canvas (`engines/canvas`):** Multi-user shared whiteboard with ActionCable WebSocket streaming, 15–30 ms coordinate throttling/batching, smoothed quadratic Bézier curves, MySQL persistence (`canvas_boards`, `canvas_strokes`), PNG high-res export, responsive 1600x900 virtual coordinates, live presence list, spectator/drawing permission gates, and admin controls (board freeze, clear board).

## 📌 Versioning & Git Commit Policy
- Always commit and push changes to git (`main` branch) immediately when finishing tasks.
- Keep the `VERSION` file updated using Semantic Versioning (SemVer) and display the current version number in all completion summaries.




