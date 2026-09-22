#!/bin/bash
# Install Shaggoth on TTY2 - Run this ON R410 locally

echo "======================================================"
echo "  Installing Shaggoth AI on TTY2"
echo "======================================================"

# Setup Python environment
cd ~/AI
if [ ! -d venv ]; then
    echo "[1/4] Creating Python virtual environment..."
    python3 -m venv venv
    echo "  ✓ Virtual environment created"
else
    echo "[1/4] Python environment already exists"
fi

echo "[2/4] Installing terminal UI dependencies..."
./venv/bin/pip install textual psutil -q
chmod +x shaggoth_tty.py
echo "  ✓ Textual UI ready"

# Create systemd service
echo "[3/4] Creating systemd service..."
sudo tee /etc/systemd/system/shaggoth-tty2.service > /dev/null << 'EOF'
[Unit]
Description=Shaggoth AI Command Center on TTY2
After=getty@tty2.service

[Service]
Type=simple
User=matt
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty2
TTYReset=yes
TTYVHangup=yes
WorkingDirectory=/home/matt/AI
ExecStart=/home/matt/AI/venv/bin/python /home/matt/AI/shaggoth_tty.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "  ✓ Service file created"

# Enable and start service
echo "[4/4] Starting Shaggoth on TTY2..."
sudo systemctl daemon-reload
sudo systemctl enable shaggoth-tty2
sudo systemctl start shaggoth-tty2

echo ""
echo "======================================================"
echo "  Installation Complete!"
echo "======================================================"
echo ""

# Show status
sudo systemctl status shaggoth-tty2 --no-pager

echo ""
echo "Shaggoth is now running on TTY2"
echo "Switch to TTY2 with: Ctrl+Alt+F2"
echo ""
