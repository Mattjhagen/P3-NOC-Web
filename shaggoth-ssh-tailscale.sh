#!/bin/bash
# SSH to R410 and start Shaggoth Command Center (Tailscale)

R410_HOST="100.65.34.60"
R410_USER="matt"

echo "Connecting to R410 Shaggoth AI..."
ssh -t ${R410_USER}@${R410_HOST} "cd ~/AI && source venv/bin/activate && python app.py"
