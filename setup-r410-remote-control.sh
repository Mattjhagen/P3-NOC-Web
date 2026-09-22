#!/bin/bash
# Configure R410 for remote control (passwordless sudo for specific commands)

R410_HOST="100.65.34.60"
R410_USER="matt"

echo "======================================================"
echo "  Setup R410 Remote Control"
echo "======================================================"
echo ""
echo "This will allow passwordless sudo for:"
echo "  - chvt (switch TTYs remotely)"
echo "  - systemctl (manage shaggoth service)"
echo ""

# Create sudoers configuration
SUDOERS_CONTENT="# Allow matt to control TTY and Shaggoth service without password
matt ALL=(ALL) NOPASSWD: /usr/bin/chvt
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl start shaggoth-tty2
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop shaggoth-tty2
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart shaggoth-tty2
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl status shaggoth-tty2
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl enable shaggoth-tty2
matt ALL=(ALL) NOPASSWD: /usr/bin/systemctl daemon-reload
matt ALL=(ALL) NOPASSWD: /usr/bin/journalctl -u shaggoth-tty2 *
matt ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/systemd/system/shaggoth-tty2.service"

echo "Configuring passwordless sudo on R410..."
echo "(You'll be prompted for R410 password ONE TIME)"
echo ""

ssh -t ${R410_USER}@${R410_HOST} "echo '${SUDOERS_CONTENT}' | sudo tee /etc/sudoers.d/r410-remote-control > /dev/null && sudo chmod 440 /etc/sudoers.d/r410-remote-control && echo '✓ Passwordless sudo configured'"

echo ""
echo "======================================================"
echo "  Setup Complete!"
echo "======================================================"
echo ""
echo "You can now remotely control R410:"
echo ""
echo "Switch to Shaggoth (TTY2):"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo chvt 2'"
echo ""
echo "Switch to GUI (TTY1):"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo chvt 1'"
echo ""
echo "Manage Shaggoth service:"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo systemctl status shaggoth-tty2'"
echo "  ssh ${R410_USER}@${R410_HOST} 'sudo systemctl restart shaggoth-tty2'"
echo ""
