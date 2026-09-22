#!/bin/bash
# Setup Automated Daily Backups to R410

echo "======================================================"
echo "  P3 Automated Backup Setup"
echo "======================================================"
echo ""

BACKUP_SCRIPT="/home/matt/P3_Official/P3-NOC-Web/backup-databases-only.sh"
FULL_BACKUP_SCRIPT="/home/matt/P3_Official/P3-NOC-Web/backup-to-r410.sh"

# Check if scripts exist
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "ERROR: Backup script not found: $BACKUP_SCRIPT"
    exit 1
fi

echo "[1/3] Setting up cron jobs..."

# Create cron jobs
(crontab -l 2>/dev/null | grep -v "P3 Database Backup\|P3 Full Backup"; cat <<CRON

# P3 Database Backup - Daily at 2 AM
0 2 * * * $BACKUP_SCRIPT >> /var/log/p3-backup.log 2>&1

# P3 Full Backup - Weekly on Sunday at 3 AM
0 3 * * 0 $FULL_BACKUP_SCRIPT >> /var/log/p3-backup.log 2>&1

CRON
) | crontab -

echo "  ✓ Cron jobs installed"

echo "[2/3] Creating log file..."
sudo touch /var/log/p3-backup.log
sudo chown matt:matt /var/log/p3-backup.log
echo "  ✓ Log file: /var/log/p3-backup.log"

echo "[3/3] Testing R410 connection..."
R410_HOST="192.168.1.48"
if ssh -o ConnectTimeout=5 matt@${R410_HOST} "echo 'Connected'" 2>/dev/null; then
    echo "  ✓ R410 connection successful"
else
    echo "  ⚠ WARNING: Cannot connect to R410"
    echo ""
    echo "You may need to set up SSH key authentication:"
    echo "  ssh-copy-id matt@${R410_HOST}"
fi

echo ""
echo "======================================================"
echo "  Automated Backups Configured!"
echo "======================================================"
echo ""
echo "Schedule:"
echo "  • Database backup: Daily at 2:00 AM"
echo "  • Full backup: Weekly on Sunday at 3:00 AM"
echo ""
echo "Backup destinations on R410:"
echo "  • Databases: ~/P3-Backups/databases/"
echo "  • Full: ~/P3-Backups/"
echo ""
echo "Manual backup commands:"
echo "  • Database only: $BACKUP_SCRIPT"
echo "  • Full backup: $FULL_BACKUP_SCRIPT"
echo ""
echo "View logs:"
echo "  tail -f /var/log/p3-backup.log"
echo ""
echo "View scheduled jobs:"
echo "  crontab -l"
echo ""
