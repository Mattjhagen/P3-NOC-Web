#!/bin/bash
# Install Shaggoth AI Command Center - Run this ON R410
# Simple version that runs locally on the target machine

set -e

echo "======================================================"
echo "  Shaggoth AI Command Center - Local Installation"
echo "======================================================"
echo "Running on: $(hostname)"
echo ""

# ============================================================
# 1. Install VNC and Desktop
# ============================================================
echo "[1/5] Installing VNC server and desktop..."
sudo apt-get update -qq
sudo apt-get install -y tigervnc-standalone-server tigervnc-common \
    xfce4 xfce4-terminal dbus-x11 python3 python3-pip python3-venv htop

# ============================================================
# 2. Setup VNC for Shaggoth
# ============================================================
echo "[2/5] Configuring VNC..."

# Create VNC password
mkdir -p ~/.vnc
echo "shaggoth1" | vncpasswd -f > ~/.vnc/passwd-shaggoth
chmod 600 ~/.vnc/passwd-shaggoth

# Create startup script
cat > ~/.vnc/xstartup-shaggoth << 'XSTART'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4 &
sleep 3
if [ -f ~/AI/app.py ]; then
    cd ~/AI
    xfce4-terminal --maximize -e "bash -c 'source venv/bin/activate && python app.py; exec bash'" &
fi
XSTART

chmod +x ~/.vnc/xstartup-shaggoth

# Create systemd service
sudo tee /etc/systemd/system/vncserver-shaggoth@.service > /dev/null << 'VNCSVC'
[Unit]
Description=Shaggoth AI Command Center VNC
After=network.target

[Service]
Type=forking
User=matt
ExecStart=/usr/bin/vncserver :%i -geometry 1920x1080 -depth 24 -localhost no -xstartup /home/matt/.vnc/xstartup-shaggoth -rfbauth /home/matt/.vnc/passwd-shaggoth
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
VNCSVC

sudo systemctl daemon-reload
sudo systemctl enable vncserver-shaggoth@2
sudo systemctl restart vncserver-shaggoth@2

echo "  ✓ VNC server configured on :2 (port 5902)"

# ============================================================
# 3. Install noVNC for Web Access
# ============================================================
echo "[3/5] Installing noVNC..."

if [ ! -d ~/noVNC-shaggoth ]; then
    git clone https://github.com/novnc/noVNC.git ~/noVNC-shaggoth
    git clone https://github.com/novnc/websockify.git ~/noVNC-shaggoth/utils/websockify
fi

pip3 install websockify --break-system-packages 2>/dev/null || pip3 install websockify

# Create noVNC service
sudo tee /etc/systemd/system/novnc-shaggoth.service > /dev/null << 'NOVNCSVC'
[Unit]
Description=noVNC for Shaggoth
After=network.target

[Service]
Type=simple
User=matt
WorkingDirectory=/home/matt/noVNC-shaggoth
ExecStart=/home/matt/noVNC-shaggoth/utils/novnc_proxy --vnc localhost:5902 --listen 6081
Restart=always

[Install]
WantedBy=multi-user.target
NOVNCSVC

sudo systemctl daemon-reload
sudo systemctl enable novnc-shaggoth
sudo systemctl restart novnc-shaggoth

echo "  ✓ Web interface on port 6081"

# ============================================================
# 4. Setup Python Environment (skip heavy packages)
# ============================================================
echo "[4/5] Setting up Python environment..."

if [ -d ~/AI ]; then
    cd ~/AI

    # Create venv if needed
    if [ ! -d venv ]; then
        python3 -m venv venv
    fi

    # Install only essential packages (skip PyTorch for now)
    echo "  - Installing Flask and basic packages..."
    ./venv/bin/pip install flask requests -q

    chmod +x *.sh 2>/dev/null || true

    echo "  ✓ Basic Python environment ready"
    echo "  ⚠ Note: Heavy packages (PyTorch) skipped for speed"
    echo "         Install manually if needed: ./venv/bin/pip install torch"
else
    echo "  ⚠ ~/AI directory not found - will be synced from R510"
fi

# ============================================================
# 5. Show Status
# ============================================================
echo ""
echo "[5/5] Checking services..."

echo ""
echo "======================================================"
echo "  Installation Complete!"
echo "======================================================"
echo ""
echo "Services:"
systemctl is-active vncserver-shaggoth@2 && echo "  ✓ VNC Server: Running" || echo "  ✗ VNC Server: Not running"
systemctl is-active novnc-shaggoth && echo "  ✓ Web Interface: Running" || echo "  ✗ Web Interface: Not running"

echo ""
echo "Access:"
echo "  Web: http://$(hostname -I | awk '{print $1}'):6081/vnc.html"
echo "  VNC: $(hostname -I | awk '{print $1}'):5902"
echo "  Password: shaggoth1"
echo ""
echo "Tailscale IP:"
tailscale ip -4 2>/dev/null && echo "  Web: http://$(tailscale ip -4):6081/vnc.html" || echo "  (Tailscale not detected)"
echo ""
