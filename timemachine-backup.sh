#!/bin/bash
# P3 Time Machine - Incremental Hourly Backups to R410
# Like Apple Time Machine: Browse and restore from any point in time

set -e

# Configuration
R410_USER="matt"
R410_HOST="192.168.1.48"
R410_BASE="/home/matt/P3-TimeMachine"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
BACKUP_NAME="${TIMESTAMP}"

# What to backup
BACKUP_SOURCES=(
    "/home/matt/P3_Official"
    "/home/matt/MailHog"
)

# What to exclude
EXCLUDES=(
    ".venv"
    "__pycache__"
    "*.pyc"
    "node_modules"
    ".git"
    "*.log"
    "*.tmp"
)

echo "======================================================"
echo "  P3 Time Machine - Incremental Backup"
echo "======================================================"
echo "Time: $(date)"
echo "Backup: ${BACKUP_NAME}"
echo ""

# ============================================================
# 1. FIND LATEST BACKUP (for hardlinking)
# ============================================================
echo "[1/4] Finding latest backup..."
LATEST=$(ssh ${R410_USER}@${R410_HOST} "ls -1t ${R410_BASE} 2>/dev/null | head -1" || echo "")

if [ -n "$LATEST" ]; then
    echo "  - Latest backup: ${LATEST}"
    LINK_DEST="--link-dest=${R410_BASE}/${LATEST}"
else
    echo "  - No previous backup found (first run)"
    LINK_DEST=""
fi

# ============================================================
# 2. CREATE RSYNC EXCLUDE ARGS
# ============================================================
EXCLUDE_ARGS=""
for pattern in "${EXCLUDES[@]}"; do
    EXCLUDE_ARGS="${EXCLUDE_ARGS} --exclude=${pattern}"
done

# ============================================================
# 3. BACKUP CODE WITH RSYNC (Incremental)
# ============================================================
echo "[2/4] Syncing code changes to R410..."

# Ensure base directory exists
ssh ${R410_USER}@${R410_HOST} "mkdir -p ${R410_BASE}/${BACKUP_NAME}"

# Sync each source with hardlinks to previous backup
for SOURCE in "${BACKUP_SOURCES[@]}"; do
    if [ -d "$SOURCE" ]; then
        SOURCE_NAME=$(basename "$SOURCE")
        echo "  - ${SOURCE_NAME}"

        rsync -az --delete ${EXCLUDE_ARGS} ${LINK_DEST} \
            "${SOURCE}/" \
            "${R410_USER}@${R410_HOST}:${R410_BASE}/${BACKUP_NAME}/${SOURCE_NAME}/" \
            2>/dev/null || echo "    Warning: Sync failed for ${SOURCE_NAME}"
    fi
done

# ============================================================
# 4. BACKUP DATABASE (Full dump every hour)
# ============================================================
echo "[3/4] Backing up databases..."

# Create temp database dump
TEMP_DB_DIR="/tmp/p3-db-${TIMESTAMP}"
mkdir -p "${TEMP_DB_DIR}"

# Dump p3lending database
docker exec p3-postgres pg_dump -U p3user -F c p3lending > "${TEMP_DB_DIR}/p3lending.dump" 2>/dev/null
docker exec p3-postgres psql -U p3user -d p3lending -t -c "SELECT COUNT(*) FROM articles;" > "${TEMP_DB_DIR}/stats.txt" 2>/dev/null || echo "0" > "${TEMP_DB_DIR}/stats.txt"

# Transfer database to R410
rsync -az "${TEMP_DB_DIR}/" \
    "${R410_USER}@${R410_HOST}:${R410_BASE}/${BACKUP_NAME}/databases/"

# Cleanup temp
rm -rf "${TEMP_DB_DIR}"

echo "  ✓ Database backed up"

# ============================================================
# 5. CREATE BACKUP METADATA
# ============================================================
echo "[4/4] Creating metadata..."

# Get stats
ARTICLE_COUNT=$(docker exec p3-postgres psql -U p3user -d p3lending -t -c "SELECT COUNT(*) FROM articles;" 2>/dev/null | xargs || echo "0")
DB_SIZE=$(docker exec p3-postgres psql -U p3user -d p3lending -t -c "SELECT pg_size_pretty(pg_database_size('p3lending'));" 2>/dev/null | xargs || echo "unknown")

# Create metadata file
ssh ${R410_USER}@${R410_HOST} "cat > ${R410_BASE}/${BACKUP_NAME}/.metadata" << EOF
timestamp=${TIMESTAMP}
date=$(date)
hostname=$(hostname)
articles=${ARTICLE_COUNT}
db_size=${DB_SIZE}
backup_type=incremental
parent_backup=${LATEST}
EOF

# ============================================================
# 6. CLEANUP OLD BACKUPS (Time Machine style)
# ============================================================
echo ""
echo "Cleaning up old backups..."

ssh ${R410_USER}@${R410_HOST} bash << 'CLEANUP_SCRIPT'
cd /home/matt/P3-TimeMachine 2>/dev/null || exit 0

# Keep:
# - All backups from last 24 hours
# - One per day for last 30 days
# - One per week after that

NOW=$(date +%s)
HOUR_AGO=$((NOW - 3600))
DAY_AGO=$((NOW - 86400))
MONTH_AGO=$((NOW - 2592000))

declare -A KEEP_DAILY
declare -A KEEP_WEEKLY

for backup in $(ls -1t); do
    # Skip if not a timestamp directory
    [[ ! "$backup" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$ ]] && continue

    # Get backup timestamp
    backup_time=$(date -d "$(echo $backup | sed 's/-/ /;s/-/ /;s/-/ /')" +%s 2>/dev/null || echo 0)

    # Keep all backups from last 24 hours
    if [ $backup_time -gt $DAY_AGO ]; then
        continue
    fi

    # Keep one per day for last 30 days
    if [ $backup_time -gt $MONTH_AGO ]; then
        day=$(echo $backup | cut -d'-' -f1-3)
        if [ -z "${KEEP_DAILY[$day]}" ]; then
            KEEP_DAILY[$day]=$backup
            continue
        fi
    fi

    # Keep one per week after 30 days
    week=$(date -d "@$backup_time" +%Y-W%U 2>/dev/null || echo "")
    if [ -n "$week" ] && [ -z "${KEEP_WEEKLY[$week]}" ]; then
        KEEP_WEEKLY[$week]=$backup
        continue
    fi

    # Delete this backup
    echo "  - Removing old backup: $backup"
    rm -rf "$backup"
done

CLEANUP_SCRIPT

# ============================================================
# 7. SHOW BACKUP SUMMARY
# ============================================================
echo ""
echo "======================================================"
echo "  Backup Complete!"
echo "======================================================"
echo ""
echo "✓ Backup saved: ${BACKUP_NAME}"
echo "✓ Database: ${ARTICLE_COUNT} articles, ${DB_SIZE}"
echo "✓ Location: ${R410_HOST}:${R410_BASE}/"
echo ""
echo "Available backups:"
ssh ${R410_USER}@${R410_HOST} "ls -lht ${R410_BASE} | head -6"
echo ""
echo "Restore from any backup:"
echo "  ./timemachine-restore.sh"
echo ""
