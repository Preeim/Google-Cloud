# Project Context & Architecture

This document serves as the master reference for future developments on this project. It contains the essential details about the tech stack, infrastructure, deployment workflow, and crucial technical limitations.

## 🏗 Infrastructure
- **Hosting:** Google Cloud Platform (GCP) Compute Engine.
  - **Machine Type:** E2-micro (0.25 vCPU, 2 GiB RAM).
  - **Region:** `europe-west1` (Belgium).
  - **OS:** Ubuntu 22.04 LTS.
- **Domain & DNS:** `bankrepo.hu` (purchased via Rackhost). A Records for `@` and `www` point to the GCP static IP.
- **Web Server:** Nginx.
  - Reverse proxy terminating SSL (via Let's Encrypt / Certbot).
  - Forwards standard HTTP/HTTPS traffic to the Puma application server running on `127.0.0.1:3000`.
  - Forwards WebSocket traffic configured under `/cable`.

## 🛠 Tech Stack
- **Ruby:** 3.3.0 (Managed via rbenv).
- **Ruby on Rails:** 7.1.4.
- **Database:** MySQL 8+.
- **Web Server:** Puma.

## ⚠️ Critical Quirks & Limitations
The server runs Ruby 3.3.0, which has a known syntax parser quirk regarding "anonymous keyword rest parameters" when gems use modern `**` block forwarding. Because of this, certain dependencies must remain tightly pinned until the server's Ruby version is upgraded:
- **Rails is pinned to `~> 7.1.4`**
- **`connection_pool` is pinned to `~> 2.4.1`**
- **`redis` is pinned to `~> 5.0`**

## 🚀 Deployment Workflow
1. **Local Development:** Write code locally on Windows and commit changes.
2. **Push to GitHub:** Commit and push changes to `https://github.com/Preeim/Google-Cloud` (`main` branch).
3. **Deploy:** 
   - SSH into the Google Cloud VM.
   - Run `./deploy.sh` (or `./deploy.sh --reset-db` for clean database re-initialization).

## 📦 Current Status
- Project has been reset to a clean slate.
- Single modern landing page rendered at `/`.
