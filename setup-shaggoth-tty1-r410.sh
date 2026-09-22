#!/bin/bash
# Setup Shaggoth AI to run on R410's physical TTY1 display

R410_HOST="100.65.34.60"
R410_USER="matt"

echo "======================================================"
echo "  Shaggoth AI - Physical Display Setup (R410 TTY1)"
echo "======================================================"
echo ""

# Copy files to R410
echo "[1/3] Copying installer to R410..."
scp install-shaggoth-tty1.sh ${R410_USER}@${R410_HOST}:~/

echo "[2/3] Syncing Shaggoth files to R410..."
rsync -az --exclude='venv' --exclude='DeepSeek-R1' --exclude='*.log' \
    ~/AI/ ${R410_USER}@${R410_HOST}:~/AI/

echo "[3/3] Running installer on R410..."
echo "  (You'll be prompted for R410 password)"
echo ""
ssh -t ${R410_USER}@${R410_HOST} "bash ~/install-shaggoth-tty1.sh"

echo ""
echo "======================================================"
echo "  Setup Complete!"
echo "======================================================"
echo ""
echo "Shaggoth AI is now running on R410's physical monitor (TTY1)"
echo ""
echo "To view status:"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo systemctl status shaggoth-tty1'"
echo ""
echo "To view logs:"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo journalctl -u shaggoth-tty1 -f'"
echo ""
echo "To stop/restart:"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo systemctl stop shaggoth-tty1'"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo systemctl restart shaggoth-tty1'"
echo ""
