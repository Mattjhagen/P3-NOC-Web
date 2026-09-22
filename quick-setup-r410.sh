#!/bin/bash
# Quick Setup - Copy installer to R410 and run it there

R410_HOST="100.65.34.60"
R410_USER="matt"

echo "======================================================"
echo "  Shaggoth R410 Quick Setup"
echo "======================================================"
echo ""

echo "[1/3] Copying installer to R410..."
scp install-shaggoth-on-r410.sh ${R410_USER}@${R410_HOST}:~/

echo "[2/3] Copying Shaggoth files to R410..."
if [ -d ~/AI ]; then
    rsync -az --exclude='venv' --exclude='DeepSeek-R1' --exclude='*.log' \
        ~/AI/ ${R410_USER}@${R410_HOST}:~/AI/
fi

if [ -d ~/Shaggoth-a1 ]; then
    rsync -az --exclude='.git' --exclude='node_modules' \
        ~/Shaggoth-a1/ ${R410_USER}@${R410_HOST}:~/Shaggoth-a1/
fi

echo "[3/3] Running installer on R410..."
echo "  (You may be prompted for R410 password for sudo commands)"
echo ""

ssh -t ${R410_USER}@${R410_HOST} "bash ~/install-shaggoth-on-r410.sh"

echo ""
echo "======================================================"
echo "  Setup Complete!"
echo "======================================================"
echo ""
echo "Access Shaggoth:"
echo "  ./shaggoth-web-tailscale.sh"
echo ""
echo "Or visit:"
echo "  http://${R410_HOST}:6081/vnc.html"
echo ""
