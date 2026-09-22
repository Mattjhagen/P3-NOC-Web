#!/bin/bash
# P3 Database-Only Backup to R410
# Runs daily to backup critical databases

set -e

# Configuration
BACKUP_DATE="$(date +%Y%m%d-%H%M%S)"
BACKUP_NAME="p3-db-backup-${BACKUP_DATE}"
LOCAL_BACKUP_DIR="/tmp/${BACKUP_NAME}"
R410_USER="matt"
R410_HOST="192.168.1.48"
R410_BACKUP_DIR="/home/matt/P3-Backups/databases"

echo "======================================================"
echo "  P3 Database Backup to R410"
echo "======================================================"
echo "Backup: ${BACKUP_NAME}"
echo "Time: $(date)"
echo ""

# Create backup directory
mkdir -p "${LOCAL_BACKUP_DIR}"
cd "${LOCAL_BACKUP_DIR}"

# ============================================================
# BACKUP ALL DATABASES
# ============================================================
echo "[1/4] Dumping PostgreSQL databases..."

# P3 Lending Database (main)
echo "  - p3lending database"
docker exec p3-postgres pg_dump -U p3user -F c -b -v -f /tmp/p3lending.dump p3lending 2>&1 | grep -v "^pg_dump:"
docker cp p3-postgres:/tmp/p3lending.dump ./p3lending.dump
docker exec p3-postgres rm /tmp/p3lending.dump

# Also create SQL dump for easy inspection
docker exec p3-postgres pg_dump -U p3user p3lending > p3lending.sql

# Backup all database schemas
docker exec p3-postgres pg_dumpall -U p3user --schema-only > schemas.sql

# Backup all database roles and permissions
docker exec p3-postgres pg_dumpall -U p3user --roles-only > roles.sql

echo "  ✓ Database dumps complete"

# ============================================================
# CREATE MANIFEST
# ============================================================
echo "[2/4] Creating manifest..."

# Get database stats
DB_SIZE=$(docker exec p3-postgres psql -U p3user -d p3lending -t -c "SELECT pg_size_pretty(pg_database_size('p3lending'));" | xargs)
ARTICLE_COUNT=$(docker exec p3-postgres psql -U p3user -d p3lending -t -c "SELECT COUNT(*) FROM articles;" 2>/dev/null | xargs || echo "0")
ANALYSIS_COUNT=$(docker exec p3-postgres psql -U p3user -d p3lending -t -c "SELECT COUNT(*) FROM analyses;" 2>/dev/null | xargs || echo "0")

cat > MANIFEST.txt << EOF
P3 Database Backup
==================
Date: $(date)
Hostname: $(hostname)
Server: R510

Database Statistics:
-------------------
Database Size: ${DB_SIZE}
Articles: ${ARTICLE_COUNT}
Analyses: ${ANALYSIS_COUNT}

Files:
------
p3lending.dump    - PostgreSQL custom format (for pg_restore)
p3lending.sql     - SQL format (human readable)
schemas.sql       - All database schemas
roles.sql         - Database roles and permissions

Restore Commands:
----------------
# Custom format (fastest):
docker cp p3lending.dump p3-postgres:/tmp/
docker exec p3-postgres pg_restore -U p3user -d p3lending --clean /tmp/p3lending.dump

# SQL format (slower but readable):
docker exec -i p3-postgres psql -U p3user -d p3lending < p3lending.sql

EOF

# ============================================================
# COMPRESS & TRANSFER
# ============================================================
echo "[3/4] Compressing and transferring to R410..."

cd /tmp
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
echo "  - Archive size: ${BACKUP_SIZE}"

# Ensure R410 backup directory exists
ssh "${R410_USER}@${R410_HOST}" "mkdir -p ${R410_BACKUP_DIR}" 2>/dev/null || {
    echo ""
    echo "WARNING: Cannot connect to R410"
    echo "Backup saved locally: /tmp/${BACKUP_NAME}.tar.gz"
    exit 1
}

# Transfer to R410
scp "/tmp/${BACKUP_NAME}.tar.gz" "${R410_USER}@${R410_HOST}:${R410_BACKUP_DIR}/"

# Cleanup old backups on R410 (keep last 30 days)
ssh "${R410_USER}@${R410_HOST}" "find ${R410_BACKUP_DIR} -name 'p3-db-backup-*.tar.gz' -mtime +30 -delete"

# Cleanup local backup
rm -rf "/tmp/${BACKUP_NAME}" "/tmp/${BACKUP_NAME}.tar.gz"

echo ""
echo "======================================================"
echo "  Database Backup Complete!"
echo "======================================================"
echo ""
echo "✓ Backed up: p3lending database"
echo "✓ Size: ${BACKUP_SIZE}"
echo "✓ Articles: ${ARTICLE_COUNT}"
echo "✓ Analyses: ${ANALYSIS_COUNT}"
echo "✓ Location: ${R410_HOST}:${R410_BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo ""
