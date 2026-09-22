#!/bin/bash
# Setup 911-Command-Center on R410 with Remote Access

set -e

R410_HOST="192.168.1.48"
R410_USER="matt"
VNC_PORT="5901"
WEB_PORT="6080"

echo "======================================================"
echo "  911-Command-Center Remote Setup on R410"
echo "======================================================"
echo ""

# Check SSH connection
echo "[1/7] Testing R410 connection..."
if ! ssh -o ConnectTimeout=5 ${R410_USER}@${R410_HOST} "echo 'Connected'" 2>/dev/null; then
    echo "ERROR: Cannot connect to R410 at ${R410_HOST}"
    echo ""
    echo "Setup SSH first:"
    echo "  ssh-copy-id ${R410_USER}@${R410_HOST}"
    exit 1
fi
echo "  ✓ Connected to R410"

# ============================================================
# OPTION 1: VNC Server Setup (Recommended)
# ============================================================
echo ""
echo "[2/7] Installing VNC server on R410..."

ssh ${R410_USER}@${R410_HOST} << 'R410_SETUP'
# Install TigerVNC and desktop environment if needed
sudo apt-get update -qq
sudo apt-get install -y tigervnc-standalone-server tigervnc-common \
    xfce4 xfce4-goodies dbus-x11 -qq 2>/dev/null || true

# Create VNC password if not exists
if [ ! -f ~/.vnc/passwd ]; then
    mkdir -p ~/.vnc
    # Set VNC password to 'p3command' (can be changed)
    echo "p3command" | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
fi

# Create VNC startup script
cat > ~/.vnc/xstartup << 'XSTARTUP'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
XSTARTUP

chmod +x ~/.vnc/xstartup

# Create systemd service for VNC
sudo tee /etc/systemd/system/vncserver@.service > /dev/null << 'VNCSERVICE'
[Unit]
Description=Remote desktop service (VNC)
After=syslog.target network.target

[Service]
Type=forking
User=matt
ExecStart=/usr/bin/vncserver :%i -geometry 1920x1080 -depth 24 -localhost no
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
VNCSERVICE

# Enable and start VNC server on display :1
sudo systemctl daemon-reload
sudo systemctl enable vncserver@1
sudo systemctl restart vncserver@1

echo "✓ VNC server installed and started"
R410_SETUP

echo "  ✓ VNC server configured on R410"

# ============================================================
# OPTION 2: noVNC Web Interface (Browser-based)
# ============================================================
echo ""
echo "[3/7] Installing noVNC for web access..."

ssh ${R410_USER}@${R410_HOST} << 'NOVNC_SETUP'
# Install noVNC and websockify
if [ ! -d ~/noVNC ]; then
    cd ~
    git clone https://github.com/novnc/noVNC.git 2>/dev/null || true
    git clone https://github.com/novnc/websockify.git noVNC/utils/websockify 2>/dev/null || true
fi

# Install Python dependencies
sudo apt-get install -y python3-pip python3-numpy -qq 2>/dev/null || true
pip3 install websockify --break-system-packages 2>/dev/null || pip3 install websockify 2>/dev/null || true

# Create noVNC systemd service
sudo tee /etc/systemd/system/novnc.service > /dev/null << 'NOVNCSERVICE'
[Unit]
Description=noVNC Web VNC Client
After=network.target vncserver@1.service

[Service]
Type=simple
User=matt
WorkingDirectory=/home/matt/noVNC
ExecStart=/home/matt/noVNC/utils/novnc_proxy --vnc localhost:5901 --listen 6080
Restart=always

[Install]
WantedBy=multi-user.target
NOVNCSERVICE

sudo systemctl daemon-reload
sudo systemctl enable novnc
sudo systemctl restart novnc

echo "✓ noVNC installed and started"
NOVNC_SETUP

echo "  ✓ noVNC web interface configured"

# ============================================================
# Copy 911-Command-Center to R410
# ============================================================
echo ""
echo "[4/7] Copying 911-Command-Center to R410..."

if [ -d ~/911-Command-Center-App ]; then
    rsync -az --exclude='node_modules' --exclude='.git' \
        ~/911-Command-Center-App/ \
        ${R410_USER}@${R410_HOST}:~/911-Command-Center-App/
    echo "  ✓ Command-Center copied to R410"
else
    echo "  ⚠ Warning: 911-Command-Center-App not found locally"
    echo "    You'll need to install it manually on R410"
fi

# ============================================================
# Install Dependencies on R410
# ============================================================
echo ""
echo "[5/7] Installing dependencies on R410..."

ssh ${R410_USER}@${R410_HOST} << 'DEPS_SETUP'
# Install Node.js if needed
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - 2>/dev/null
    sudo apt-get install -y nodejs -qq 2>/dev/null || true
fi

# Install Python dependencies
sudo apt-get install -y python3-pip python3-venv -qq 2>/dev/null || true

# Install command-center dependencies if directory exists
if [ -d ~/911-Command-Center-App ]; then
    cd ~/911-Command-Center-App

    # Install npm dependencies if package.json exists
    if [ -f package.json ]; then
        npm install --legacy-peer-deps 2>/dev/null || npm install 2>/dev/null || true
    fi

    # Setup Python venv if requirements.txt exists
    if [ -f requirements.txt ]; then
        python3 -m venv venv
        ./venv/bin/pip install -r requirements.txt 2>/dev/null || true
    fi
fi

echo "✓ Dependencies installed"
DEPS_SETUP

echo "  ✓ Dependencies installed"

# ============================================================
# Create Auto-start Script
# ============================================================
echo ""
echo "[6/7] Creating auto-start configuration..."

ssh ${R410_USER}@${R410_HOST} << 'AUTOSTART_SETUP'
# Create autostart directory
mkdir -p ~/.config/autostart

# Create desktop entry for auto-start
cat > ~/.config/autostart/command-center.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=911-Command-Center
Exec=/home/matt/911-Command-Center-App/start.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
DESKTOP

# Create start script if doesn't exist
if [ ! -f ~/911-Command-Center-App/start.sh ]; then
    cat > ~/911-Command-Center-App/start.sh << 'STARTSCRIPT'
#!/bin/bash
cd ~/911-Command-Center-App

# Start the application based on what's available
if [ -f package.json ]; then
    npm start
elif [ -f main.py ]; then
    python3 main.py
elif [ -f app.py ]; then
    python3 app.py
else
    # Try to start electron app
    npx electron .
fi
STARTSCRIPT
    chmod +x ~/911-Command-Center-App/start.sh
fi

echo "✓ Auto-start configured"
AUTOSTART_SETUP

echo "  ✓ Auto-start configured"

# ============================================================
# Create Connection Helper Scripts
# ============================================================
echo ""
echo "[7/7] Creating connection helper scripts..."

# VNC connection script
cat > ~/P3_Official/P3-NOC-Web/connect-r410-vnc.sh << 'VNC_CONNECT'
#!/bin/bash
# Connect to R410 Command-Center via VNC

R410_HOST="192.168.1.48"

echo "Connecting to R410 Command-Center via VNC..."
echo ""
echo "VNC Server: ${R410_HOST}:5901"
echo "Password: p3command"
echo ""

# Try to open VNC client
if command -v vncviewer &> /dev/null; then
    vncviewer ${R410_HOST}:5901
elif command -v remmina &> /dev/null; then
    remmina -c vnc://${R410_HOST}:5901
else
    echo "Install a VNC client:"
    echo "  Ubuntu: sudo apt install tigervnc-viewer"
    echo "  Mac: Download RealVNC Viewer"
    echo ""
    echo "Then connect to: ${R410_HOST}:5901"
fi
VNC_CONNECT

# Web browser connection script
cat > ~/P3_Official/P3-NOC-Web/connect-r410-web.sh << 'WEB_CONNECT'
#!/bin/bash
# Connect to R410 Command-Center via Web Browser

R410_HOST="192.168.1.48"
WEB_URL="http://${R410_HOST}:6080/vnc.html"

echo "======================================================"
echo "  R410 Command-Center Web Access"
echo "======================================================"
echo ""
echo "Opening: ${WEB_URL}"
echo ""
echo "If browser doesn't open, visit:"
echo "  ${WEB_URL}"
echo ""

# Try to open in browser
if command -v xdg-open &> /dev/null; then
    xdg-open "${WEB_URL}"
elif command -v open &> /dev/null; then
    open "${WEB_URL}"
else
    echo "Visit the URL above in your browser"
fi
WEB_CONNECT

# SSH X11 forwarding script
cat > ~/P3_Official/P3-NOC-Web/connect-r410-x11.sh << 'X11_CONNECT'
#!/bin/bash
# Connect to R410 with X11 forwarding (slower but simple)

R410_HOST="192.168.1.48"
R410_USER="matt"

echo "Connecting with X11 forwarding..."
echo "After connecting, run:"
echo "  cd ~/911-Command-Center-App"
echo "  ./start.sh"
echo ""

ssh -X ${R410_USER}@${R410_HOST}
X11_CONNECT

chmod +x ~/P3_Official/P3-NOC-Web/connect-r410-*.sh

echo "  ✓ Connection scripts created"

# ============================================================
# Summary
# ============================================================
echo ""
echo "======================================================"
echo "  Setup Complete!"
echo "======================================================"
echo ""
echo "R410 Services Status:"
ssh ${R410_USER}@${R410_HOST} "systemctl status vncserver@1 --no-pager | head -3; systemctl status novnc --no-pager | head -3"

echo ""
echo "======================================================"
echo "  Connection Options"
echo "======================================================"
echo ""
echo "1. WEB BROWSER (Easiest - Recommended)"
echo "   URL: http://${R410_HOST}:6080/vnc.html"
echo "   Script: ./connect-r410-web.sh"
echo ""
echo "2. VNC CLIENT (Best Performance)"
echo "   Server: ${R410_HOST}:5901"
echo "   Password: p3command"
echo "   Script: ./connect-r410-vnc.sh"
echo ""
echo "3. SSH X11 FORWARDING (Slowest)"
echo "   Script: ./connect-r410-x11.sh"
echo ""
echo "Change VNC password:"
echo "  ssh ${R410_USER}@${R410_HOST} vncpasswd"
echo ""
echo "Restart VNC server:"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo systemctl restart vncserver@1'"
echo ""
