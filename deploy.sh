#!/bin/bash
set -e

echo "====================================================="
echo "   Starting Deployment on Google Cloud VM"
echo "====================================================="

# 1. Ensure Port 80 -> 3000 redirect is active
if ! sudo iptables -t nat -C PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 3000 2>/dev/null; then
    echo "[1/5] Setting up port 80 -> 3000 forwarding..."
    sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 3000
else
    echo "[1/5] Port forwarding (80 -> 3000) already active."
fi

# 2. Pull latest changes
echo "[2/5] Pulling latest code from GitHub..."
git pull origin main

# 3. Install bundle dependencies
echo "[3/5] Checking Gem dependencies..."
bundle install

# 4. Migrate database (creates if not exists, then runs migrations)
echo "[4/5] Preparing database & migrations..."
chmod +x bin/* || true
bin/rails db:prepare

# 5. Restart server
echo "[5/5] Restarting Rails server..."
PID=$(pgrep -f "puma.*3000" || true)
if [ -n "$PID" ]; then
    echo "Stopping current server process (PID: $PID)..."
    kill -9 $PID || true
    sleep 2
fi

# Ensure log directory exists
mkdir -p log

echo "Starting Rails in background (logs -> log/server.log)..."
nohup bin/rails server -b 0.0.0.0 -p 3000 > log/server.log 2>&1 &

sleep 3
if pgrep -f "puma.*3000" > /dev/null; then
    echo "====================================================="
    echo "   Deployment Complete! Live site is up and running."
    echo "====================================================="
else
    echo "====================================================="
    echo "   Notice: Check log/server.log for startup status."
    echo "====================================================="
fi
