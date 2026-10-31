#!/bin/bash
set -e

echo "=== Deploying to bankrepo.hu ==="

# Load environment variables if present
for env_file in ".env" ".env.production"; do
    [ -f "$env_file" ] && set -a && source "$env_file" && set +a
done

# Ensure database password alias
[ -n "$DB_PASSWORD" ] && [ -z "$DATABASE_PASSWORD" ] && export DATABASE_PASSWORD="$DB_PASSWORD"

# 1. Sync repository
echo "-> Updating code..."
git fetch origin main
git reset --hard origin/main
git clean -fd

# 2. Dependencies
echo "-> Installing dependencies..."
bundle install --quiet

# 3. Security & Secrets
chmod +x bin/* || true
if [ -z "$SECRET_KEY_BASE" ] && [ ! -f ".secret_key_base" ]; then
    openssl rand -hex 64 > .secret_key_base
    chmod 600 .secret_key_base
fi

# 4. Cache & Database
echo "-> Clearing cache and preparing database..."
mkdir -p log tmp/pids tmp/cache
RAILS_ENV=production bundle exec rails tmp:clear db:prepare

# 5. Restart application
echo "-> Restarting service..."
SUDO_CMD=""
[ "$EUID" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO_CMD="sudo"

if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q "banks-hub.service"; then
    $SUDO_CMD systemctl restart banks-hub
    sleep 2
    if $SUDO_CMD systemctl is-active --quiet banks-hub; then
        echo "=== Deployment Complete! https://bankrepo.hu is running. ==="
        exit 0
    fi
fi

# Fallback: process restart
PIDS=$(pgrep -f "puma.*3000" || true)
[ -n "$PIDS" ] && echo "$PIDS" | xargs -r kill -9 2>/dev/null || true
rm -f tmp/pids/server.pid
RAILS_ENV=production nohup bundle exec rails server -e production -b 0.0.0.0 -p 3000 > log/server.log 2>&1 &
echo "=== Deployment Complete (background process started)! ==="
