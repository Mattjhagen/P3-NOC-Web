#!/bin/bash
# Setup Shaggoth AI Command Center on R410 via Tailscale (v2 - Passwordless)
# DeepSeek-R1 671B Training Interface

set -e

R410_HOST="100.65.34.60"
R410_USER="matt"
VNC_PORT="5902"
WEB_PORT="6081"

echo "======================================================"
echo "  Shaggoth AI Command Center - R410 Tailscale Setup"
echo "======================================================"
echo "DeepSeek-R1 671B Training Interface"
echo "Target: ${R410_HOST} (R410 via Tailscale)"
echo ""

# Check and setup SSH keys if needed
echo "[1/8] Setting up SSH keys for R410 Tailscale..."

# Generate SSH key if doesn't exist
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "  - Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa -q
    echo "  ✓ SSH key generated"
fi

# Test connection
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes ${R410_USER}@${R410_HOST} "echo 'Connected'" 2>/dev/null; then
    echo "  - SSH key not configured on R410"
    echo "  - Copying SSH key to R410..."
    echo ""
    echo "You will be prompted for the R410 password:"
    echo ""
    ssh-copy-id -o ConnectTimeout=15 ${R410_USER}@${R410_HOST} || exit 1
    echo "  ✓ SSH key copied successfully"
else
    echo "  ✓ SSH already configured"
fi

echo "  ✓ Tailscale connection verified"

# ============================================================
# Setup Passwordless Sudo on R410
# ============================================================
echo ""
echo "[2/8] Setting up passwordless sudo on R410..."

echo "  - Creating sudoers configuration..."
echo "  - You'll be prompted for R410 password ONE MORE TIME to enable passwordless sudo"
echo ""

# Create sudoers file for Shaggoth operations
ssh -t ${R410_USER}@${R410_HOST} 'bash -s' << 'SUDO_SETUP'
# Create sudoers file for Shaggoth setup
sudo tee /etc/sudoers.d/shaggoth-setup > /dev/null << 'SUDOERS_EOF'
# Shaggoth AI Setup - Passwordless sudo for required commands
matt ALL=(ALL) NOPASSWD: /usr/bin/apt-get update
matt ALL=(ALL) NOPASSWD: /usr/bin/apt-get install *
matt ALL=(ALL) NOPASSWD: /usr/bin/apt-get upgrade *
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl daemon-reload
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl enable *
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl disable *
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl start *
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop *
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart *
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl status *
matt ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/systemd/system/*
SUDOERS_EOF

sudo chmod 0440 /etc/sudoers.d/shaggoth-setup
echo "✓ Passwordless sudo configured"
SUDO_SETUP

echo "  ✓ Passwordless sudo enabled for setup commands"

# ============================================================
# Install VNC Server for Shaggoth
# ============================================================
echo ""
echo "[3/8] Setting up VNC server on R410..."

ssh ${R410_USER}@${R410_HOST} << 'R410_VNC'
# Install TigerVNC and lightweight desktop
echo "  - Installing VNC server and desktop..."
sudo apt-get update -qq 2>/dev/null
sudo apt-get install -y tigervnc-standalone-server tigervnc-common \
    xfce4 xfce4-terminal dbus-x11 -qq 2>/dev/null || true

# Create VNC password for Shaggoth (shaggoth1)
mkdir -p ~/.vnc
echo "shaggoth1" | vncpasswd -f > ~/.vnc/passwd-shaggoth 2>/dev/null
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

# Enable and start VNC on display :2
sudo systemctl daemon-reload
sudo systemctl enable vncserver-shaggoth@2 2>/dev/null || true
sudo systemctl restart vncserver-shaggoth@2 2>/dev/null || true

echo "✓ Shaggoth VNC server configured"
R410_VNC

echo "  ✓ VNC server running on display :2"

# ============================================================
# Install noVNC for Web Browser Access
# ============================================================
echo ""
echo "[4/8] Setting up web browser access..."

ssh ${R410_USER}@${R410_HOST} << 'NOVNC'
# Install noVNC if not already present
if [ ! -d ~/noVNC-shaggoth ]; then
    cd ~
    git clone https://github.com/novnc/noVNC.git noVNC-shaggoth 2>/dev/null || true
    git clone https://github.com/novnc/websockify.git noVNC-shaggoth/utils/websockify 2>/dev/null || true
fi

# Install websockify
pip3 install websockify --break-system-packages -q 2>/dev/null || pip3 install websockify -q 2>/dev/null || true

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
sudo systemctl enable novnc-shaggoth 2>/dev/null || true
sudo systemctl restart novnc-shaggoth 2>/dev/null || true

echo "✓ noVNC configured for web access"
NOVNC

echo "  ✓ Web interface available on port 6081"

# ============================================================
# Copy Shaggoth AI Trainer to R410
# ============================================================
echo ""
echo "[5/8] Syncing Shaggoth AI trainer to R410 via Tailscale..."

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
echo "[6/8] Installing Shaggoth dependencies on R410..."

ssh ${R410_USER}@${R410_HOST} << 'DEPS'
# Install Python and dependencies
echo "  - Installing Python packages..."
sudo apt-get install -y python3 python3-pip python3-venv python3-flask \
    htop -qq 2>/dev/null || true

# Setup AI trainer environment
if [ -d ~/AI ]; then
    cd ~/AI

    # Create virtual environment if doesn't exist
    if [ ! -d venv ]; then
        python3 -m venv venv
    fi

    # Install requirements
    if [ -f requirements.txt ]; then
        echo "  - Installing Python requirements..."
        ./venv/bin/pip install -r requirements.txt -q 2>/dev/null || true
    fi

    # Make scripts executable
    chmod +x *.sh 2>/dev/null || true
fi

echo "✓ Dependencies installed"
DEPS

echo "  ✓ Dependencies ready"

# ============================================================
# Create Connection Scripts
# ============================================================
echo ""
echo "[7/8] Creating Tailscale connection scripts..."

# Web browser connection
cat > ~/P3_Official/P3-NOC-Web/shaggoth-web-tailscale.sh << EOF
#!/bin/bash
R410_HOST="${R410_HOST}"
WEB_URL="http://\${R410_HOST}:6081/vnc.html"

echo "Opening Shaggoth AI Command Center..."
echo "URL: \${WEB_URL}"

if command -v xdg-open &> /dev/null; then
    xdg-open "\${WEB_URL}"
elif command -v open &> /dev/null; then
    open "\${WEB_URL}"
else
    echo "Visit: \${WEB_URL}"
fi
EOF

# VNC client connection
cat > ~/P3_Official/P3-NOC-Web/shaggoth-vnc-tailscale.sh << EOF
#!/bin/bash
R410_HOST="${R410_HOST}"

echo "Connecting to Shaggoth via VNC..."
echo "Server: \${R410_HOST}:5902"
echo "Password: shaggoth1"

if command -v vncviewer &> /dev/null; then
    vncviewer \${R410_HOST}:5902
else
    echo "Install: sudo apt install tigervnc-viewer"
fi
EOF

# SSH connection
cat > ~/P3_Official/P3-NOC-Web/shaggoth-ssh-tailscale.sh << EOF
#!/bin/bash
R410_HOST="${R410_HOST}"
R410_USER="${R410_USER}"

ssh -t \${R410_USER}@\${R410_HOST} "cd ~/AI && source venv/bin/activate && python app.py"
EOF

chmod +x ~/P3_Official/P3-NOC-Web/shaggoth-*-tailscale.sh

# ============================================================
# Create Sync Script
# ============================================================
echo ""
echo "[8/8] Creating sync script..."

cat > ~/P3_Official/P3-NOC-Web/sync-shaggoth-tailscale.sh << EOF
#!/bin/bash
R410_HOST="${R410_HOST}"
R410_USER="${R410_USER}"

echo "Syncing Shaggoth AI to R410..."

[ -d ~/AI ] && rsync -az --delete --exclude='venv' --exclude='DeepSeek-R1' ~/AI/ \${R410_USER}@\${R410_HOST}:~/AI/
[ -d ~/Shaggoth-a1 ] && rsync -az --delete --exclude='.git' ~/Shaggoth-a1/ \${R410_USER}@\${R410_HOST}:~/Shaggoth-a1/

echo "✓ Sync complete"
EOF

chmod +x ~/P3_Official/P3-NOC-Web/sync-shaggoth-tailscale.sh

echo "  ✓ Connection scripts created"

# ============================================================
# Summary
# ============================================================
echo ""
echo "======================================================"
echo "  Shaggoth Command Center Ready!"
echo "======================================================"
echo ""

# Check services
ssh ${R410_USER}@${R410_HOST} "systemctl is-active vncserver-shaggoth@2 >/dev/null 2>&1 && echo '  ✓ VNC Server: Running' || echo '  ⚠ VNC Server: Not running'"
ssh ${R410_USER}@${R410_HOST} "systemctl is-active novnc-shaggoth >/dev/null 2>&1 && echo '  ✓ Web Interface: Running' || echo '  ⚠ Web Interface: Not running'"

echo ""
echo "Connect via:"
echo "  Web:  ./shaggoth-web-tailscale.sh"
echo "  VNC:  ./shaggoth-vnc-tailscale.sh"
echo "  SSH:  ./shaggoth-ssh-tailscale.sh"
echo ""
echo "URL: http://${R410_HOST}:6081/vnc.html"
echo ""
