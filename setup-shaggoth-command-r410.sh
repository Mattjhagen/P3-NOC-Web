#!/bin/bash
# Setup Shaggoth AI Command Center on R410 with Remote Access
# DeepSeek-R1 671B Training Interface

set -e

R410_HOST="192.168.1.48"
R410_USER="matt"
VNC_PORT="5902"  # Different port from other VNC
WEB_PORT="6081"  # Different port from other web services

echo "======================================================"
echo "  Shaggoth AI Command Center - R410 Remote Setup"
echo "======================================================"
echo "DeepSeek-R1 671B Training Interface"
echo ""

# Check and setup SSH keys if needed
echo "[1/7] Setting up SSH keys for R410..."

# Generate SSH key if doesn't exist
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "  - Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa -q
    echo "  ✓ SSH key generated"
fi

# Test connection
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes ${R410_USER}@${R410_HOST} "echo 'Connected'" 2>/dev/null; then
    echo "  - SSH key not configured on R410"
    echo "  - Copying SSH key to R410..."
    echo ""
    echo "You will be prompted for the R410 password (one time only):"
    echo ""

    ssh-copy-id -o ConnectTimeout=10 ${R410_USER}@${R410_HOST} || {
        echo ""
        echo "ERROR: Failed to copy SSH key to R410"
        echo ""
        echo "Please verify:"
        echo "  1. R410 is online at ${R410_HOST}"
        echo "  2. SSH server is running on R410"
        echo "  3. You know the password for ${R410_USER}@${R410_HOST}"
        echo ""
        echo "Manual setup:"
        echo "  ssh-copy-id ${R410_USER}@${R410_HOST}"
        exit 1
    }

    echo ""
    echo "  ✓ SSH key copied successfully"
else
    echo "  ✓ SSH already configured"
fi

# Verify connection works
echo "  - Testing connection..."
if ! ssh -o ConnectTimeout=5 ${R410_USER}@${R410_HOST} "echo 'Connected'" 2>/dev/null; then
    echo "ERROR: Still cannot connect to R410"
    exit 1
fi
echo "  ✓ Connection verified"

# ============================================================
# Install VNC Server for Shaggoth
# ============================================================
echo ""
echo "[2/7] Setting up VNC server on R410..."

ssh ${R410_USER}@${R410_HOST} << 'R410_VNC'
# Install TigerVNC and lightweight desktop
sudo apt-get update -qq
sudo apt-get install -y tigervnc-standalone-server tigervnc-common \
    xfce4 xfce4-terminal dbus-x11 -qq 2>/dev/null || true

# Create VNC password for Shaggoth (shaggoth1)
mkdir -p ~/.vnc
echo "shaggoth1" | vncpasswd -f > ~/.vnc/passwd-shaggoth
chmod 600 ~/.vnc/passwd-shaggoth

# Create Shaggoth VNC startup script
cat > ~/.vnc/xstartup-shaggoth << 'XSTART'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start XFCE desktop
exec startxfce4 &

# Wait for desktop to load
sleep 3

# Auto-start Shaggoth command center
if [ -f ~/AI/app.py ]; then
    cd ~/AI
    xfce4-terminal --maximize -e "bash -c 'source venv/bin/activate && python app.py; exec bash'" &
fi
XSTART

chmod +x ~/.vnc/xstartup-shaggoth

# Create systemd service for Shaggoth VNC
sudo tee /etc/systemd/system/vncserver-shaggoth@.service > /dev/null << 'VNCSVC'
[Unit]
Description=Shaggoth AI Command Center VNC
After=syslog.target network.target

[Service]
Type=forking
User=matt
ExecStart=/usr/bin/vncserver :%i -geometry 1920x1080 -depth 24 -localhost no -xstartup /home/matt/.vnc/xstartup-shaggoth -rfbauth /home/matt/.vnc/passwd-shaggoth
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
VNCSVC

# Enable and start VNC on display :2 (port 5902)
sudo systemctl daemon-reload
sudo systemctl enable vncserver-shaggoth@2
sudo systemctl restart vncserver-shaggoth@2

echo "✓ Shaggoth VNC server configured"
R410_VNC

echo "  ✓ VNC server running on display :2"

# ============================================================
# Install noVNC for Web Browser Access
# ============================================================
echo ""
echo "[3/7] Setting up web browser access..."

ssh ${R410_USER}@${R410_HOST} << 'NOVNC'
# Install noVNC if not already present
if [ ! -d ~/noVNC-shaggoth ]; then
    cd ~
    git clone https://github.com/novnc/noVNC.git noVNC-shaggoth 2>/dev/null || true
    git clone https://github.com/novnc/websockify.git noVNC-shaggoth/utils/websockify 2>/dev/null || true
fi

# Install websockify
sudo apt-get install -y python3-pip -qq 2>/dev/null || true
pip3 install websockify --break-system-packages 2>/dev/null || pip3 install websockify 2>/dev/null || true

# Create noVNC service for Shaggoth
sudo tee /etc/systemd/system/novnc-shaggoth.service > /dev/null << 'NOVNCSVC'
[Unit]
Description=noVNC for Shaggoth AI Command Center
After=network.target vncserver-shaggoth@2.service

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

echo "✓ noVNC configured for web access"
NOVNC

echo "  ✓ Web interface available on port 6081"

# ============================================================
# Copy Shaggoth AI Trainer to R410
# ============================================================
echo ""
echo "[4/7] Syncing Shaggoth AI trainer to R410..."

if [ -d ~/AI ]; then
    echo "  - Copying AI trainer..."
    rsync -az --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' \
        --exclude='DeepSeek-R1' --exclude='*.log' \
        ~/AI/ ${R410_USER}@${R410_HOST}:~/AI/
    echo "  ✓ AI trainer synced"
else
    echo "  ⚠ Warning: ~/AI not found locally"
fi

if [ -d ~/Shaggoth-a1 ]; then
    echo "  - Copying Shaggoth platform..."
    rsync -az --exclude='.git' --exclude='node_modules' \
        ~/Shaggoth-a1/ ${R410_USER}@${R410_HOST}:~/Shaggoth-a1/
    echo "  ✓ Shaggoth platform synced"
fi

# ============================================================
# Install Dependencies on R410
# ============================================================
echo ""
echo "[5/7] Installing Shaggoth dependencies on R410..."

ssh ${R410_USER}@${R410_HOST} << 'DEPS'
# Install Python and dependencies
sudo apt-get install -y python3 python3-pip python3-venv python3-flask \
    python3-torch python3-numpy -qq 2>/dev/null || true

# Setup AI trainer environment
if [ -d ~/AI ]; then
    cd ~/AI

    # Create virtual environment if doesn't exist
    if [ ! -d venv ]; then
        python3 -m venv venv
    fi

    # Install requirements
    if [ -f requirements.txt ]; then
        ./venv/bin/pip install -r requirements.txt -q 2>/dev/null || true
    fi

    # Make scripts executable
    chmod +x *.sh 2>/dev/null || true
fi

# Install GPU monitoring tools
sudo apt-get install -y nvidia-smi htop -qq 2>/dev/null || true

echo "✓ Dependencies installed"
DEPS

echo "  ✓ Dependencies ready"

# ============================================================
# Create Connection Scripts
# ============================================================
echo ""
echo "[6/7] Creating connection scripts..."

# Web browser connection (easiest)
cat > ~/P3_Official/P3-NOC-Web/shaggoth-web.sh << 'WEB'
#!/bin/bash
# Access Shaggoth Command Center via Web Browser

R410_HOST="192.168.1.48"
WEB_URL="http://${R410_HOST}:6081/vnc.html"

echo "======================================================"
echo "  Shaggoth AI Command Center - Web Access"
echo "======================================================"
echo ""
echo "Opening: ${WEB_URL}"
echo ""
echo "The DeepSeek-R1 training interface will load automatically"
echo ""

# Open browser
if command -v xdg-open &> /dev/null; then
    xdg-open "${WEB_URL}"
elif command -v open &> /dev/null; then
    open "${WEB_URL}"
else
    echo "Visit: ${WEB_URL}"
fi
WEB

# VNC client connection
cat > ~/P3_Official/P3-NOC-Web/shaggoth-vnc.sh << 'VNC'
#!/bin/bash
# Connect to Shaggoth via VNC Client

R410_HOST="192.168.1.48"

echo "======================================================"
echo "  Shaggoth AI Command Center - VNC"
echo "======================================================"
echo ""
echo "Server: ${R410_HOST}:5902"
echo "Password: shaggoth1"
echo ""

if command -v vncviewer &> /dev/null; then
    vncviewer ${R410_HOST}:5902
elif command -v remmina &> /dev/null; then
    remmina -c vnc://${R410_HOST}:5902
else
    echo "Install VNC client: sudo apt install tigervnc-viewer"
fi
VNC

# SSH direct connection
cat > ~/P3_Official/P3-NOC-Web/shaggoth-ssh.sh << 'SSH'
#!/bin/bash
# SSH to R410 and start Shaggoth Command Center

R410_HOST="192.168.1.48"
R410_USER="matt"

echo "Connecting to R410 Shaggoth AI..."
ssh -t ${R410_USER}@${R410_HOST} "cd ~/AI && source venv/bin/activate && python app.py"
SSH

chmod +x ~/P3_Official/P3-NOC-Web/shaggoth-*.sh

echo "  ✓ Connection scripts created"

# ============================================================
# Setup Time Machine Sync for Shaggoth
# ============================================================
echo ""
echo "[7/7] Setting up Shaggoth sync to R410..."

# Create sync script for keeping R410 updated
cat > ~/P3_Official/P3-NOC-Web/sync-shaggoth-to-r410.sh << 'SYNC'
#!/bin/bash
# Sync Shaggoth AI changes to R410

R410_HOST="192.168.1.48"
R410_USER="matt"

echo "Syncing Shaggoth AI to R410..."

# Sync AI trainer
if [ -d ~/AI ]; then
    echo "  - Syncing ~/AI/..."
    rsync -az --delete --exclude='venv' --exclude='__pycache__' \
        --exclude='DeepSeek-R1' --exclude='*.log' \
        ~/AI/ ${R410_USER}@${R410_HOST}:~/AI/
fi

# Sync Shaggoth platform
if [ -d ~/Shaggoth-a1 ]; then
    echo "  - Syncing ~/Shaggoth-a1/..."
    rsync -az --delete --exclude='.git' --exclude='node_modules' \
        ~/Shaggoth-a1/ ${R410_USER}@${R410_HOST}:~/Shaggoth-a1/
fi

echo "✓ Sync complete"
SYNC

chmod +x ~/P3_Official/P3-NOC-Web/sync-shaggoth-to-r410.sh

echo "  ✓ Sync script created: ./sync-shaggoth-to-r410.sh"

# ============================================================
# Summary
# ============================================================
echo ""
echo "======================================================"
echo "  Shaggoth Command Center Ready on R410!"
echo "======================================================"
echo ""
echo "Services Status:"
ssh ${R410_USER}@${R410_HOST} "systemctl status vncserver-shaggoth@2 --no-pager | head -3; systemctl status novnc-shaggoth --no-pager | head -3"

echo ""
echo "======================================================"
echo "  Connection Methods"
echo "======================================================"
echo ""
echo "1. WEB BROWSER (Recommended)"
echo "   URL: http://${R410_HOST}:6081/vnc.html"
echo "   Script: ./shaggoth-web.sh"
echo "   - No client needed"
echo "   - Training interface auto-starts"
echo ""
echo "2. VNC CLIENT (Best Performance)"
echo "   Server: ${R410_HOST}:5902"
echo "   Password: shaggoth1"
echo "   Script: ./shaggoth-vnc.sh"
echo ""
echo "3. SSH TERMINAL (Command Line)"
echo "   Script: ./shaggoth-ssh.sh"
echo "   - Direct terminal access"
echo "   - CLI training controls"
echo ""
echo "Shaggoth AI Trainer:"
echo "  Location: ~/AI/ on R410"
echo "  Interface: DeepSeek-R1 671B"
echo "  Platform: ~/Shaggoth-a1/ on R410"
echo ""
echo "Monitor GPU:"
echo "  ssh ${R410_USER}@${R410_HOST} nvidia-smi"
echo ""
echo "Change VNC password:"
echo "  ssh ${R410_USER}@${R410_HOST}"
echo "  echo 'newpass' | vncpasswd -f > ~/.vnc/passwd-shaggoth"
echo ""
