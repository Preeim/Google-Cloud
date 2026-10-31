#!/bin/bash
set -e

echo "====================================================="
echo "   Deploying Clean Slate to bankrepo.hu"
echo "====================================================="

# Load environment variables if present
for env_file in ".env" ".env.production"; do
    [ -f "$env_file" ] && set -a && source "$env_file" && set +a
done

# Ensure database password alias
[ -n "$DB_PASSWORD" ] && [ -z "$DATABASE_PASSWORD" ] && export DATABASE_PASSWORD="$DB_PASSWORD"

# 1. Sync repository
echo "-> Updating code from GitHub..."
git fetch origin main
git reset --hard origin/main
git clean -fd

# 2. Dependencies
echo "-> Checking Gem dependencies..."
bundle install --quiet

# 3. Security & Secrets
chmod +x bin/* || true
if [ -z "$SECRET_KEY_BASE" ]; then
    if [ -f ".secret_key_base" ]; then
        export SECRET_KEY_BASE=$(cat .secret_key_base | tr -d '\r\n')
    else
        GENERATED_SECRET=$(openssl rand -hex 64 2>/dev/null || bundle exec ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")
        echo "$GENERATED_SECRET" > .secret_key_base
        chmod 600 .secret_key_base
        export SECRET_KEY_BASE="$GENERATED_SECRET"
    fi
fi

# 4. Cache & Database
echo "-> Clearing cache and preparing database..."
mkdir -p log tmp/pids tmp/cache
rm -f tmp/pids/server.pid
RAILS_ENV=production bundle exec rails tmp:clear db:prepare

# 5. Restart application
echo "-> Restarting application server on port 3000..."
SUDO_CMD=""
[ "$EUID" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO_CMD="sudo"

STARTED_VIA_SYSTEMD=false

# Try systemd service if available
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q "banks-hub.service"; then
    echo "Attempting restart via systemd (banks-hub)..."
    $SUDO_CMD systemctl restart banks-hub || true
    sleep 3
    if curl -s -f http://127.0.0.1:3000/up >/dev/null 2>&1; then
        STARTED_VIA_SYSTEMD=true
        echo "Successfully started via systemd!"
    else
        echo "systemd did not respond on port 3000, switching to standalone process..."
        $SUDO_CMD systemctl stop banks-hub 2>/dev/null || true
    fi
fi

# Fallback: Start background puma/rails process directly
if [ "$STARTED_VIA_SYSTEMD" = false ]; then
    echo "Starting Rails Puma server in background..."
    PIDS=$(pgrep -f "puma.*3000" || pgrep -f "rails.*3000" || true)
    [ -n "$PIDS" ] && echo "$PIDS" | xargs -r kill -9 2>/dev/null || true
    rm -f tmp/pids/server.pid
    RAILS_ENV=production nohup bundle exec rails server -e production -b 127.0.0.1 -p 3000 > log/server.log 2>&1 &
fi

# 6. Verify health check on port 3000
echo "-> Verifying server is listening on port 3000..."
SERVER_OK=false
for i in {1..20}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/up || true)
    if [ "$STATUS" == "200" ]; then
        SERVER_OK=true
        break
    fi
    sleep 1
done

if [ "$SERVER_OK" = true ]; then
    echo "====================================================="
    echo "   Deployment Complete! Live site is UP and RUNNING."
    echo "   URL: https://bankrepo.hu"
    echo "====================================================="
else
    echo "====================================================="
    echo "⚠️ Server verification failed! Details:"
    echo "====================================================="
    [ -f "log/server.log" ] && tail -n 40 log/server.log || true
    exit 1
fi
