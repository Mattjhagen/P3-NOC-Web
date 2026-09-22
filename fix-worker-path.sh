#!/bin/bash
# Fix bitcoin-worker PATH to include /snap/bin for OpenCode

echo "Fixing bitcoin-worker service PATH..."
sudo cp /tmp/bitcoin-worker-real.service /etc/systemd/system/bitcoin-worker.service
sudo systemctl daemon-reload
sudo systemctl restart bitcoin-worker

echo ""
echo "Waiting 5 seconds for worker to process..."
sleep 5

echo ""
echo "Checking status:"
sudo journalctl -u bitcoin-worker -n 10 --no-pager | grep -E "INFO|ERROR|WARNING"

echo ""
echo "✓ Service updated and restarted"
echo ""
echo "The worker will now process articles every 5 minutes."
echo "Check logs: sudo journalctl -u bitcoin-worker -f"
