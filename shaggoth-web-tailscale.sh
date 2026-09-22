#!/bin/bash
# Access Shaggoth Command Center via Web Browser (Tailscale)

R410_HOST="100.65.34.60"
WEB_URL="http://${R410_HOST}:6081/vnc.html"

echo "======================================================"
echo "  Shaggoth AI Command Center - Web Access"
echo "======================================================"
echo ""
echo "Opening: ${WEB_URL}"
echo "Password: shaggoth1"
echo ""

# Open browser
if command -v xdg-open &> /dev/null; then
    xdg-open "${WEB_URL}"
elif command -v open &> /dev/null; then
    open "${WEB_URL}"
else
    echo "Visit: ${WEB_URL}"
fi
