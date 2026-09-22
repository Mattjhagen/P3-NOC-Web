#!/bin/bash
# Connect to Shaggoth via VNC Client (Tailscale)

R410_HOST="100.65.34.60"

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
    echo ""
    echo "Or use web browser: http://${R410_HOST}:6081/vnc.html"
fi
