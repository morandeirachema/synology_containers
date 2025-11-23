#!/bin/bash
##################################################
# Synology Container Stack - Backup Script
# Backs up all configuration and data
##################################################

set -e

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="synology-stack-backup_${TIMESTAMP}"
RETENTION_DAYS=30

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Synology Container Stack - Backup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

echo -e "${YELLOW}📦 Starting backup process...${NC}"

# Backup environment file (if exists)
if [ -f ".env" ]; then
    echo "💾 Backing up .env file..."
    cp .env "$BACKUP_DIR/$BACKUP_NAME/"
fi

# Backup docker-compose
echo "💾 Backing up docker-compose.yml..."
cp docker-compose.yml "$BACKUP_DIR/$BACKUP_NAME/"

# Backup all configurations
echo "💾 Backing up configurations..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME/configs.tar.gz" config/ 2>/dev/null || true

# Backup Vaultwarden data
if [ -d "data/vaultwarden" ]; then
    echo "💾 Backing up Vaultwarden..."
    tar -czf "$BACKUP_DIR/$BACKUP_NAME/vaultwarden.tar.gz" data/vaultwarden/
fi

# Backup Nextcloud database
if docker ps | grep -q nextcloud-db; then
    echo "💾 Backing up Nextcloud database..."
    docker exec nextcloud-db mysqldump -u nextcloud -p${NEXTCLOUD_DB_PASSWORD:-password} nextcloud > "$BACKUP_DIR/$BACKUP_NAME/nextcloud-db.sql"
fi

# Backup Paperless database
if docker ps | grep -q paperless-db; then
    echo "💾 Backing up Paperless database..."
    docker exec paperless-db pg_dump -U paperless paperless > "$BACKUP_DIR/$BACKUP_NAME/paperless-db.sql"
fi

# Backup Immich database
if docker ps | grep -q immich-postgres; then
    echo "💾 Backing up Immich database..."
    docker exec immich-postgres pg_dump -U postgres immich > "$BACKUP_DIR/$BACKUP_NAME/immich-db.sql"
fi

# Backup Home Assistant
if [ -d "config/homeassistant" ]; then
    echo "💾 Backing up Home Assistant..."
    tar -czf "$BACKUP_DIR/$BACKUP_NAME/homeassistant.tar.gz" config/homeassistant/
fi

# Backup Authelia
if [ -d "config/authelia" ]; then
    echo "💾 Backing up Authelia..."
    tar -czf "$BACKUP_DIR/$BACKUP_NAME/authelia.tar.gz" config/authelia/
fi

# Backup Node-RED flows
if [ -d "config/nodered" ]; then
    echo "💾 Backing up Node-RED..."
    tar -czf "$BACKUP_DIR/$BACKUP_NAME/nodered.tar.gz" config/nodered/
fi

# Backup Prometheus data
if [ -d "data/prometheus" ]; then
    echo "💾 Backing up Prometheus..."
    tar -czf "$BACKUP_DIR/$BACKUP_NAME/prometheus.tar.gz" data/prometheus/ 2>/dev/null || true
fi

# Backup Grafana dashboards
if [ -d "data/grafana" ]; then
    echo "💾 Backing up Grafana..."
    tar -czf "$BACKUP_DIR/$BACKUP_NAME/grafana.tar.gz" data/grafana/ 2>/dev/null || true
fi

# Backup Uptime Kuma
if [ -d "data/uptime-kuma" ]; then
    echo "💾 Backing up Uptime Kuma..."
    tar -czf "$BACKUP_DIR/$BACKUP_NAME/uptime-kuma.tar.gz" data/uptime-kuma/
fi

# Create final archive
echo "📦 Creating final backup archive..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

# Calculate size
BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)

echo ""
echo -e "${GREEN}✅ Backup completed successfully!${NC}"
echo -e "${GREEN}📦 Backup file: $BACKUP_DIR/${BACKUP_NAME}.tar.gz${NC}"
echo -e "${GREEN}📊 Size: $BACKUP_SIZE${NC}"
echo ""

# Cleanup old backups
echo -e "${YELLOW}🧹 Cleaning up backups older than $RETENTION_DAYS days...${NC}"
find "$BACKUP_DIR" -name "synology-stack-backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete

echo -e "${GREEN}✅ Backup process complete!${NC}"
echo ""
echo "💡 Tips:"
echo "  - Store backups off-site for disaster recovery"
echo "  - Test restore procedures regularly"
echo "  - Consider encrypting backups containing sensitive data"
echo ""
