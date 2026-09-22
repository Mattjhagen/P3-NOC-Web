#!/bin/bash
# Setup passwordless sudo for P3NOC service management

echo "======================================================"
echo "  P3NOC Passwordless Sudo Setup"
echo "======================================================"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run with sudo"
    echo "Usage: sudo ./setup-passwordless-sudo.sh"
    exit 1
fi

echo "[1/3] Creating sudoers configuration..."

# Create sudoers file with correct permissions
cat > /tmp/p3noc-sudoers << 'EOF'
# P3NOC Dashboard - Passwordless sudo for service management
# Allow user matt to restart services without password

matt ALL=(ALL) NOPASSWD: /bin/systemctl restart bitcoin-worker
matt ALL=(ALL) NOPASSWD: /bin/systemctl restart bitcoin-ingest
matt ALL=(ALL) NOPASSWD: /bin/systemctl restart bitcoin-ingest.timer
matt ALL=(ALL) NOPASSWD: /bin/systemctl restart ollama
matt ALL=(ALL) NOPASSWD: /bin/systemctl start bitcoin-worker
matt ALL=(ALL) NOPASSWD: /bin/systemctl start bitcoin-ingest
matt ALL=(ALL) NOPASSWD: /bin/systemctl start bitcoin-ingest.timer
matt ALL=(ALL) NOPASSWD: /bin/systemctl start ollama
matt ALL=(ALL) NOPASSWD: /bin/systemctl stop bitcoin-worker
matt ALL=(ALL) NOPASSWD: /bin/systemctl stop bitcoin-ingest
matt ALL=(ALL) NOPASSWD: /bin/systemctl stop bitcoin-ingest.timer
matt ALL=(ALL) NOPASSWD: /bin/systemctl stop ollama
EOF

echo "[2/3] Validating sudoers syntax..."

# Validate syntax before installing
if visudo -c -f /tmp/p3noc-sudoers; then
    echo "  ✓ Syntax valid"
else
    echo "  ✗ Syntax error - aborting"
    rm /tmp/p3noc-sudoers
    exit 1
fi

echo "[3/3] Installing sudoers configuration..."

# Install with correct permissions
install -m 0440 /tmp/p3noc-sudoers /etc/sudoers.d/p3noc
rm /tmp/p3noc-sudoers

echo ""
echo "======================================================"
echo "  Passwordless Sudo Configured!"
echo "======================================================"
echo ""
echo "User 'matt' can now run these commands without password:"
echo "  - sudo systemctl restart bitcoin-worker"
echo "  - sudo systemctl restart bitcoin-ingest"
echo "  - sudo systemctl restart bitcoin-ingest.timer"
echo "  - sudo systemctl restart ollama"
echo ""
echo "F6, F7 in P3NOC will now work without password prompts."
echo ""
