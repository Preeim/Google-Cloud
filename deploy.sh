#!/bin/bash
set -e

echo "====================================================="
echo "   Starting Deployment on Google Cloud VM"
echo "====================================================="

# Nginx handles port 80 & 443 proxying to port 3000


# 2. Pull latest changes
echo "[2/5] Pulling latest code from GitHub..."
git pull origin main

# 3. Install bundle dependencies
echo "[3/5] Checking Gem dependencies..."
bundle install

# 4. Migrate database (creates if not exists, then runs migrations)
echo "[4/5] Preparing database & migrations..."
chmod +x bin/* || true

# Ensure SECRET_KEY_BASE is available for production commands
if [ -z "$SECRET_KEY_BASE" ]; then
    if [ -f ".secret_key_base" ]; then
        export SECRET_KEY_BASE=$(cat .secret_key_base | tr -d '\r\n')
    else
        GENERATED_SECRET=$(bundle exec ruby -e "require 'securerandom'; puts SecureRandom.hex(64)" 2>/dev/null || openssl rand -hex 64)
        echo "$GENERATED_SECRET" > .secret_key_base
        chmod 600 .secret_key_base
        export SECRET_KEY_BASE="$GENERATED_SECRET"
    fi
fi

# Run database migrations
RAILS_ENV=production bundle exec rails db:prepare

# 5. Restart server
echo "[5/5] Restarting Rails server..."
PID=$(pgrep -f "puma.*3000" || pgrep -f "rails.*3000" || true)
if [ -n "$PID" ]; then
    echo "Stopping current server process (PID: $PID)..."
    kill -9 $PID 2>/dev/null || true
    sleep 2
fi

# Ensure log and pids directory exist and remove stale server.pid
mkdir -p log tmp/pids
rm -f tmp/pids/server.pid

echo "Starting Rails in background (logs -> log/server.log)..."
RAILS_ENV=production nohup bundle exec rails server -e production -b 0.0.0.0 -p 3000 > log/server.log 2>&1 &

sleep 4
if pgrep -f "puma.*3000" > /dev/null || pgrep -f "rails.*3000" > /dev/null; then
    echo "====================================================="
    echo "   Deployment Complete! Live site is up and running."
    echo "====================================================="
else
    echo "====================================================="
    echo "   Warning: Server may still be booting or failed. Log:"
    echo "====================================================="
    tail -n 35 log/server.log || true
fi
