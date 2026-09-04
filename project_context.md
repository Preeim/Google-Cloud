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
2. **Push to GitHub:** Commit and push changes to `https://github.com/Preeim/Google-Cloud` (`main` branch).
3. **Deploy:** 
   - SSH into the Google Cloud VM.
   - Run `./deploy.sh` from the `~/Google-Cloud` directory.
   - The script automatically: pulls from git, installs bundle dependencies, runs database migrations, and restarts the Puma daemon.

## 📦 Current Features & Architecture
- **Architecture:** Modular Monolith with isolated In-App Rails Engines mounted under `/engines` (e.g. `Chess::Engine` mounted at `/chess` with `chess_` database table prefix).
- **Authentication & RBAC:** Custom secure auth via `has_secure_password` (bcrypt) with `User` roles (`user`, `moderator`, `admin`), `ActiveSession` (SHA-256 hashed session tracking), brute-force account lockout (15 minutes after 5 failed attempts), and `AuditLog` security event tracking.
- **Administration:** Dedicated `/bank-admin` management portal for platform owner (Bánk) to supervise users, toggle module availability (maintenance/active), view audit logs, and monitor telemetry.
- **Security:** Content Security Policy (CSP) with Action Cable WSS support, parameter log masking, rate limiter middleware, and secure cookie configuration.
- **Testing Console:** Action Cable WebSocket testing area preserved at `/test`.
- **Frontend Styling:** Bespoke Deep Dark Theme (`#0a0f1d` canvas, `#11192e` surface, `#1a243b` elevated, `#38bdf8` accent, `#a855f7` admin accent; specifically non-#000000) with a 3-state Top Navigation Bar and App Launcher sidebar.


