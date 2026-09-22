#!/bin/bash
# Complete RSS Feed Setup for P3NOC

set -e

echo "======================================================"
echo "  P3NOC RSS Feed System Setup"
echo "======================================================"

echo "[1/4] Installing RSS worker service..."
sudo cp /tmp/bitcoin-worker-real.service /etc/systemd/system/bitcoin-worker.service
sudo systemctl daemon-reload
echo "  ✓ Service installed"

echo "[2/4] Starting RSS worker..."
sudo systemctl stop bitcoin-worker 2>/dev/null || true
sudo systemctl start bitcoin-worker
sudo systemctl enable bitcoin-worker
echo "  ✓ Worker started"

echo "[3/4] Waiting for first RSS poll (10 seconds)..."
sleep 10

echo "[4/4] Checking status..."
sudo systemctl status bitcoin-worker --no-pager | head -15

echo ""
echo "======================================================"
echo "  RSS Feed System Active!"
echo "======================================================"
echo ""
echo "Configuration:"
echo "  ✓ Database: p3lending"
echo "  ✓ RSS Feeds: 5 sources (CoinDesk, Cointelegraph, etc.)"
echo "  ✓ AI Analysis: Gemini 3 Flash"
echo "  ✓ Poll Interval: 5 minutes"
echo ""
echo "Check logs:"
echo "  sudo journalctl -u bitcoin-worker -f"
echo ""
echo "Check articles:"
echo "  docker exec p3-postgres psql -U p3user -d p3lending -c 'SELECT COUNT(*) FROM articles;'"
echo ""
echo "The news feed in P3NOC will populate within 5-10 minutes!"
echo ""
