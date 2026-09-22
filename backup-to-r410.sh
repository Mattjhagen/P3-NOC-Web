#!/bin/bash
# P3 Services Backup to R410
# Backs up all P3 services, databases, configs, and code to r410 server

set -e

# Configuration
BACKUP_NAME="p3-backup-$(date +%Y%m%d-%H%M%S)"
LOCAL_BACKUP_DIR="/tmp/${BACKUP_NAME}"
R410_USER="matt"
R410_HOST="192.168.1.48"  # Adjust if needed
R410_BACKUP_DIR="/home/matt/P3-Backups"

echo "======================================================"
echo "  P3 Services Backup to R410"
echo "======================================================"
echo "Backup name: ${BACKUP_NAME}"
echo "R410 target: ${R410_USER}@${R410_HOST}:${R410_BACKUP_DIR}"
echo ""

# Create local backup directory
mkdir -p "${LOCAL_BACKUP_DIR}"
cd "${LOCAL_BACKUP_DIR}"

# ============================================================
# 1. BACKUP CODE & WEB FILES
# ============================================================
echo "[1/8] Backing up P3 codebase..."
mkdir -p code
cd code

# P3 Official (NOC, Website, API)
echo "  - P3_Official directory"
rsync -az --exclude='.venv' --exclude='__pycache__' --exclude='*.pyc' \
    --exclude='node_modules' --exclude='.git' \
    /home/matt/P3_Official/ ./P3_Official/

# MailHog
if [ -d /home/matt/MailHog ]; then
    echo "  - MailHog"
    rsync -az --exclude='node_modules' /home/matt/MailHog/ ./MailHog/
fi

cd ..

# ============================================================
# 2. BACKUP DATABASES
# ============================================================
echo "[2/8] Backing up PostgreSQL databases..."
mkdir -p databases

# P3 Lending Database
echo "  - p3lending database"
docker exec p3-postgres pg_dump -U p3user p3lending > databases/p3lending.sql 2>/dev/null || \
    echo "    Warning: Could not dump p3lending database"

# ============================================================
# 3. BACKUP DOCKER CONFIGS & VOLUMES
# ============================================================
echo "[3/8] Backing up Docker configurations..."
mkdir -p docker

# Export docker-compose files
find /home/matt/P3_Official -name "docker-compose*.yml" -exec cp {} docker/ \; 2>/dev/null || true

# List running containers
docker ps --format "{{.Names}}" > docker/running-containers.txt

# ============================================================
# 4. BACKUP SYSTEMD SERVICES
# ============================================================
echo "[4/8] Backing up systemd services..."
mkdir -p systemd

# Copy P3 related service files
for service in bitcoin-worker bitcoin-ingest; do
    if [ -f "/etc/systemd/system/${service}.service" ]; then
        echo "  - ${service}.service"
        sudo cp "/etc/systemd/system/${service}.service" systemd/
    fi
    if [ -f "/etc/systemd/system/${service}.timer" ]; then
        echo "  - ${service}.timer"
        sudo cp "/etc/systemd/system/${service}.timer" systemd/
    fi
done

# Copy sudoers config if exists
if [ -f /etc/sudoers.d/p3noc ]; then
    echo "  - p3noc sudoers"
    sudo cp /etc/sudoers.d/p3noc systemd/
fi

# ============================================================
# 5. BACKUP ENVIRONMENT FILES & CONFIGS
# ============================================================
echo "[5/8] Backing up configuration files..."
mkdir -p configs

# .env files (sensitive!)
find /home/matt/P3_Official -name ".env" -exec cp --parents {} configs/ \; 2>/dev/null || true

# Nginx configs (if any)
if [ -d /etc/nginx/sites-available ]; then
    sudo cp -r /etc/nginx/sites-available configs/nginx-sites/ 2>/dev/null || true
fi

# ============================================================
# 6. BACKUP DEPLOYMENT CONFIGS
# ============================================================
echo "[6/8] Backing up deployment configurations..."
mkdir -p deployments

# Cloudflare tunnel configs
if [ -f /home/matt/.cloudflared/config.yml ]; then
    cp /home/matt/.cloudflared/config.yml deployments/cloudflare-tunnel.yml 2>/dev/null || true
fi

# Fly.io configs
find /home/matt/P3_Official -name "fly.toml" -exec cp --parents {} deployments/ \; 2>/dev/null || true

# ============================================================
# 7. CREATE BACKUP MANIFEST
# ============================================================
echo "[7/8] Creating backup manifest..."
cat > MANIFEST.txt << EOF
P3 Services Backup
==================
Date: $(date)
Hostname: $(hostname)
Server: R510

Contents:
---------
code/P3_Official/           - Main P3 codebase (NOC, Web, API)
code/MailHog/              - Mail testing service
databases/p3lending.sql    - PostgreSQL database dump
docker/                    - Docker configs and container list
systemd/                   - Systemd service files
configs/                   - Environment files and configurations
deployments/               - Deployment configs (Cloudflare, Fly.io)

Services Backed Up:
------------------
✓ P3 NOC Dashboard (TTY)
✓ P3 NOC Web (admin.p3lending.space)
✓ P3 Lending Website (p3lending.space)
✓ MailHog (mail service)
✓ RSS Worker (bitcoin-worker.service)
✓ PostgreSQL Database (p3lending)
✓ API Services
✓ Systemd Services
✓ Configuration Files

Restore Instructions:
--------------------
1. Copy backup from r410: scp -r ${R410_USER}@${R410_HOST}:${R410_BACKUP_DIR}/${BACKUP_NAME} /tmp/
2. Run: /tmp/${BACKUP_NAME}/restore-from-backup.sh

EOF

# ============================================================
# 8. CREATE RESTORE SCRIPT
# ============================================================
echo "[7/8] Creating restore script..."
cat > restore-from-backup.sh << 'RESTORE_EOF'
#!/bin/bash
# P3 Services Restore Script
# Restores all P3 services from backup

set -e

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================================"
echo "  P3 Services Restore"
echo "======================================================"
echo "Restoring from: ${BACKUP_DIR}"
echo ""

read -p "This will OVERWRITE existing P3 services. Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
echo "[1/6] Restoring codebase..."
rsync -az "${BACKUP_DIR}/code/P3_Official/" /home/matt/P3_Official/
if [ -d "${BACKUP_DIR}/code/MailHog" ]; then
    rsync -az "${BACKUP_DIR}/code/MailHog/" /home/matt/MailHog/
fi

echo "[2/6] Restoring databases..."
if [ -f "${BACKUP_DIR}/databases/p3lending.sql" ]; then
    echo "  - Restoring p3lending database"
    docker exec -i p3-postgres psql -U p3user -d p3lending < "${BACKUP_DIR}/databases/p3lending.sql"
fi

echo "[3/6] Restoring systemd services..."
if [ -d "${BACKUP_DIR}/systemd" ]; then
    sudo cp "${BACKUP_DIR}"/systemd/*.service /etc/systemd/system/ 2>/dev/null || true
    sudo cp "${BACKUP_DIR}"/systemd/*.timer /etc/systemd/system/ 2>/dev/null || true
    if [ -f "${BACKUP_DIR}/systemd/p3noc" ]; then
        sudo cp "${BACKUP_DIR}/systemd/p3noc" /etc/sudoers.d/
        sudo chmod 0440 /etc/sudoers.d/p3noc
    fi
    sudo systemctl daemon-reload
fi

echo "[4/6] Restoring configurations..."
if [ -d "${BACKUP_DIR}/configs" ]; then
    # Restore .env files
    find "${BACKUP_DIR}/configs" -name ".env" -exec bash -c 'cp "$1" "${1#${BACKUP_DIR}/configs/}"' _ {} \;
fi

echo "[5/6] Reinstalling Python dependencies..."
if [ -d /home/matt/P3_Official/P3-NOC-Web ]; then
    cd /home/matt/P3_Official/P3-NOC-Web
    python3 -m venv .venv
    .venv/bin/pip install -r requirements.txt > /dev/null 2>&1 || true
fi

echo "[6/6] Restarting services..."
sudo systemctl restart bitcoin-worker || true
sudo systemctl restart bitcoin-ingest || true
docker restart p3-postgres || true

echo ""
echo "======================================================"
echo "  Restore Complete!"
echo "======================================================"
echo ""
echo "Services restored. Check status:"
echo "  systemctl status bitcoin-worker"
echo "  docker ps"
echo "  p3noc  # Start dashboard"
echo ""
RESTORE_EOF

chmod +x restore-from-backup.sh

# ============================================================
# 9. COMPRESS & TRANSFER TO R410
# ============================================================
echo "[8/8] Transferring backup to R410..."

# Create compressed archive
cd /tmp
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
echo "  - Archive size: ${BACKUP_SIZE}"

# Ensure backup directory exists on r410
ssh "${R410_USER}@${R410_HOST}" "mkdir -p ${R410_BACKUP_DIR}" 2>/dev/null || {
    echo ""
    echo "ERROR: Cannot connect to R410 at ${R410_HOST}"
    echo ""
    echo "Backup created locally at: /tmp/${BACKUP_NAME}.tar.gz"
    echo ""
    echo "Manual transfer:"
    echo "  scp /tmp/${BACKUP_NAME}.tar.gz ${R410_USER}@${R410_HOST}:${R410_BACKUP_DIR}/"
    echo ""
    exit 1
}

# Transfer to r410
echo "  - Transferring to R410..."
scp "/tmp/${BACKUP_NAME}.tar.gz" "${R410_USER}@${R410_HOST}:${R410_BACKUP_DIR}/"

# Extract on r410 and keep compressed copy
ssh "${R410_USER}@${R410_HOST}" "cd ${R410_BACKUP_DIR} && tar -xzf ${BACKUP_NAME}.tar.gz"

# List backups on r410
echo ""
echo "Backups on R410:"
ssh "${R410_USER}@${R410_HOST}" "ls -lh ${R410_BACKUP_DIR}/ | tail -5"

# Cleanup local backup
rm -rf "/tmp/${BACKUP_NAME}" "/tmp/${BACKUP_NAME}.tar.gz"

echo ""
echo "======================================================"
echo "  Backup Complete!"
echo "======================================================"
echo ""
echo "✓ Backup saved to R410: ${R410_BACKUP_DIR}/${BACKUP_NAME}"
echo "✓ Size: ${BACKUP_SIZE}"
echo ""
echo "To restore from R410:"
echo "  1. scp -r ${R410_USER}@${R410_HOST}:${R410_BACKUP_DIR}/${BACKUP_NAME} /tmp/"
echo "  2. /tmp/${BACKUP_NAME}/restore-from-backup.sh"
echo ""
