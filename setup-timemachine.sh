#!/bin/bash
# Setup P3 Time Machine - Hourly Incremental Backups

echo "======================================================"
echo "  P3 Time Machine Setup"
echo "======================================================"
echo ""

BACKUP_SCRIPT="/home/matt/P3_Official/P3-NOC-Web/timemachine-backup.sh"
RESTORE_SCRIPT="/home/matt/P3_Official/P3-NOC-Web/timemachine-restore.sh"
R410_HOST="192.168.1.48"

# Check scripts exist
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "ERROR: Backup script not found"
    exit 1
fi

echo "[1/4] Testing R410 connection..."
if ssh -o ConnectTimeout=5 matt@${R410_HOST} "mkdir -p ~/P3-TimeMachine" 2>/dev/null; then
    echo "  ✓ R410 connected and backup directory created"
else
    echo "  ✗ Cannot connect to R410"
    echo ""
    echo "Set up SSH key authentication first:"
    echo "  ssh-copy-id matt@${R410_HOST}"
    exit 1
fi

echo "[2/4] Running initial backup..."
$BACKUP_SCRIPT

echo ""
echo "[3/4] Setting up hourly cron job..."

# Remove old backup crons
crontab -l 2>/dev/null | grep -v "P3 Time Machine\|P3 Database Backup\|P3 Full Backup" > /tmp/crontab.tmp

# Add hourly Time Machine backup
cat >> /tmp/crontab.tmp << CRON

# P3 Time Machine - Hourly incremental backup
0 * * * * $BACKUP_SCRIPT >> /var/log/p3-timemachine.log 2>&1

CRON

# Install crontab
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp

echo "  ✓ Hourly backup scheduled"

echo "[4/4] Creating log file..."
sudo touch /var/log/p3-timemachine.log
sudo chown matt:matt /var/log/p3-timemachine.log
echo "  ✓ Log file created"

echo ""
echo "======================================================"
echo "  P3 Time Machine Active!"
echo "======================================================"
echo ""
echo "Backup Schedule:"
echo "  • Every hour on the hour"
echo "  • Incremental (only changed files)"
echo "  • Uses hardlinks to save space"
echo ""
echo "Retention Policy:"
echo "  • Last 24 hours: All hourly backups"
echo "  • Last 30 days: One backup per day"
echo "  • After 30 days: One backup per week"
echo ""
echo "Storage Location:"
echo "  • R410: ~/P3-TimeMachine/"
echo ""
echo "Commands:"
echo "  • Manual backup: $BACKUP_SCRIPT"
echo "  • Restore/browse: $RESTORE_SCRIPT"
echo "  • View log: tail -f /var/log/p3-timemachine.log"
echo "  • List backups: ssh matt@${R410_HOST} 'ls -lht ~/P3-TimeMachine | head -20'"
echo ""
echo "Next backup: Top of the hour"
echo "Current time: $(date)"
echo ""
