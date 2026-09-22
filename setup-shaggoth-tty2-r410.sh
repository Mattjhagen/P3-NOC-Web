#!/bin/bash
# Setup Shaggoth AI to run on R410's physical TTY2 display

R410_HOST="100.65.34.60"
R410_USER="matt"

echo "======================================================"
echo "  Shaggoth AI - Physical Display Setup (R410 TTY2)"
echo "======================================================"
echo ""

# Copy files to R410
echo "[1/3] Copying installer to R410..."
scp install-shaggoth-tty2.sh ${R410_USER}@${R410_HOST}:~/

echo "[2/3] Syncing Shaggoth files to R410..."
rsync -az --exclude='venv' --exclude='DeepSeek-R1' --exclude='*.log' \
    ~/AI/ ${R410_USER}@${R410_HOST}:~/AI/

echo "[3/3] Running installer on R410..."
echo "  (You'll be prompted for R410 password)"
echo ""
ssh -t ${R410_USER}@${R410_HOST} "bash ~/install-shaggoth-tty2.sh"

echo ""
echo "======================================================"
echo "  Setup Complete!"
echo "======================================================"
echo ""
echo "Shaggoth AI is now running on R410 TTY2"
echo "Switch to TTY2: Ctrl+Alt+F2"
echo "Back to GUI: Ctrl+Alt+F1"
echo ""
echo "To view status:"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo systemctl status shaggoth-tty2'"
echo ""
echo "To view logs:"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo journalctl -u shaggoth-tty2 -f'"
echo ""
echo "To stop/restart:"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo systemctl stop shaggoth-tty2'"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo systemctl restart shaggoth-tty2'"
echo ""
