#!/bin/bash
# P3 Time Machine - Browse and Restore from Backups

set -e

R410_USER="matt"
R410_HOST="192.168.1.48"
R410_BASE="/home/matt/P3-TimeMachine"

echo "======================================================"
echo "  P3 Time Machine - Restore"
echo "======================================================"
echo ""

# ============================================================
# 1. LIST AVAILABLE BACKUPS
# ============================================================
echo "Fetching available backups from R410..."
echo ""

# Get backup list with metadata
BACKUPS=$(ssh ${R410_USER}@${R410_HOST} "cd ${R410_BASE} && for d in \$(ls -1t); do
    if [ -f \"\$d/.metadata\" ]; then
        timestamp=\$(grep '^timestamp=' \"\$d/.metadata\" | cut -d'=' -f2)
        date=\$(grep '^date=' \"\$d/.metadata\" | cut -d'=' -f2-)
        articles=\$(grep '^articles=' \"\$d/.metadata\" | cut -d'=' -f2)
        echo \"\$d|\$date|\$articles\"
    fi
done")

if [ -z "$BACKUPS" ]; then
    echo "No backups found on R410."
    exit 1
fi

# Display backups
echo "Available backups:"
echo "=================="
echo ""

i=1
declare -a BACKUP_LIST
while IFS='|' read -r timestamp date articles; do
    BACKUP_LIST[$i]="$timestamp"

    # Parse timestamp for display
    year=$(echo $timestamp | cut -d'-' -f1)
    month=$(echo $timestamp | cut -d'-' -f2)
    day=$(echo $timestamp | cut -d'-' -f3)
    time=$(echo $timestamp | cut -d'-' -f4)
    hour="${time:0:2}"
    min="${time:2:2}"

    # Calculate age
    backup_epoch=$(date -d "${year}-${month}-${day} ${hour}:${min}" +%s 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    age_hours=$(( (now_epoch - backup_epoch) / 3600 ))

    if [ $age_hours -lt 24 ]; then
        age="${age_hours}h ago"
    elif [ $age_hours -lt 168 ]; then
        age="$((age_hours / 24))d ago"
    else
        age="$((age_hours / 168))w ago"
    fi

    printf "%2d) %s  %-15s  %s articles\n" $i "$date" "($age)" "$articles"
    ((i++))
done <<< "$BACKUPS"

echo ""
echo "0) Cancel"
echo ""

# ============================================================
# 2. SELECT BACKUP
# ============================================================
read -p "Select backup to restore (1-$((i-1))): " selection

if [ "$selection" = "0" ] || [ -z "$selection" ]; then
    echo "Restore cancelled."
    exit 0
fi

if [ "$selection" -lt 1 ] || [ "$selection" -ge "$i" ]; then
    echo "Invalid selection."
    exit 1
fi

SELECTED_BACKUP="${BACKUP_LIST[$selection]}"
echo ""
echo "Selected backup: ${SELECTED_BACKUP}"
echo ""

# ============================================================
# 3. SELECT WHAT TO RESTORE
# ============================================================
echo "What do you want to restore?"
echo "============================="
echo ""
echo "1) Everything (code + databases)"
echo "2) Code only (P3_Official, MailHog)"
echo "3) Databases only (p3lending)"
echo "4) Browse backup (copy to /tmp for inspection)"
echo "0) Cancel"
echo ""

read -p "Select option (1-4): " restore_option

case $restore_option in
    1)
        RESTORE_CODE=true
        RESTORE_DB=true
        ;;
    2)
        RESTORE_CODE=true
        RESTORE_DB=false
        ;;
    3)
        RESTORE_CODE=false
        RESTORE_DB=true
        ;;
    4)
        echo ""
        echo "Copying backup to /tmp/p3-browse-${SELECTED_BACKUP} for inspection..."
        scp -r "${R410_USER}@${R410_HOST}:${R410_BASE}/${SELECTED_BACKUP}" "/tmp/p3-browse-${SELECTED_BACKUP}"
        echo ""
        echo "✓ Backup copied to: /tmp/p3-browse-${SELECTED_BACKUP}"
        echo ""
        echo "Browse:"
        echo "  cd /tmp/p3-browse-${SELECTED_BACKUP}"
        echo "  ls -lah"
        echo ""
        exit 0
        ;;
    0|*)
        echo "Restore cancelled."
        exit 0
        ;;
esac

# ============================================================
# 4. CONFIRM RESTORE
# ============================================================
echo ""
echo "⚠️  WARNING: This will OVERWRITE current files/databases!"
echo ""
read -p "Type 'YES' to confirm restore: " confirm

if [ "$confirm" != "YES" ]; then
    echo "Restore cancelled."
    exit 0
fi

# ============================================================
# 5. RESTORE CODE
# ============================================================
if [ "$RESTORE_CODE" = true ]; then
    echo ""
    echo "Restoring code from backup..."

    # P3_Official
    if ssh ${R410_USER}@${R410_HOST} "[ -d ${R410_BASE}/${SELECTED_BACKUP}/P3_Official ]"; then
        echo "  - P3_Official"
        rsync -az --delete \
            "${R410_USER}@${R410_HOST}:${R410_BASE}/${SELECTED_BACKUP}/P3_Official/" \
            /home/matt/P3_Official/
    fi

    # MailHog
    if ssh ${R410_USER}@${R410_HOST} "[ -d ${R410_BASE}/${SELECTED_BACKUP}/MailHog ]"; then
        echo "  - MailHog"
        rsync -az --delete \
            "${R410_USER}@${R410_HOST}:${R410_BASE}/${SELECTED_BACKUP}/MailHog/" \
            /home/matt/MailHog/
    fi

    echo "  ✓ Code restored"
fi

# ============================================================
# 6. RESTORE DATABASE
# ============================================================
if [ "$RESTORE_DB" = true ]; then
    echo ""
    echo "Restoring database from backup..."

    # Copy database dump from R410
    TEMP_DB="/tmp/restore-db-$$"
    mkdir -p "$TEMP_DB"

    scp "${R410_USER}@${R410_HOST}:${R410_BASE}/${SELECTED_BACKUP}/databases/p3lending.dump" "$TEMP_DB/"

    # Stop services that use the database
    echo "  - Stopping services..."
    sudo systemctl stop bitcoin-worker 2>/dev/null || true

    # Drop and recreate database
    echo "  - Recreating database..."
    docker exec p3-postgres psql -U p3user -d postgres -c "DROP DATABASE IF EXISTS p3lending;" 2>/dev/null || true
    docker exec p3-postgres psql -U p3user -d postgres -c "CREATE DATABASE p3lending OWNER p3user;" 2>/dev/null || true

    # Restore from dump
    echo "  - Restoring data..."
    docker cp "$TEMP_DB/p3lending.dump" p3-postgres:/tmp/
    docker exec p3-postgres pg_restore -U p3user -d p3lending --no-owner /tmp/p3lending.dump 2>/dev/null || true
    docker exec p3-postgres rm /tmp/p3lending.dump

    # Restart services
    echo "  - Restarting services..."
    sudo systemctl start bitcoin-worker 2>/dev/null || true

    # Cleanup
    rm -rf "$TEMP_DB"

    echo "  ✓ Database restored"
fi

# ============================================================
# 7. VERIFY RESTORE
# ============================================================
echo ""
echo "Verifying restore..."

if [ "$RESTORE_DB" = true ]; then
    ARTICLE_COUNT=$(docker exec p3-postgres psql -U p3user -d p3lending -t -c "SELECT COUNT(*) FROM articles;" 2>/dev/null | xargs || echo "error")
    echo "  - Database articles: ${ARTICLE_COUNT}"
fi

echo ""
echo "======================================================"
echo "  Restore Complete!"
echo "======================================================"
echo ""
echo "✓ Restored from: ${SELECTED_BACKUP}"

if [ "$RESTORE_CODE" = true ]; then
    echo "✓ Code restored to: /home/matt/P3_Official/"
fi

if [ "$RESTORE_DB" = true ]; then
    echo "✓ Database restored: p3lending"
fi

echo ""
echo "Services status:"
systemctl status bitcoin-worker --no-pager | head -3
echo ""
