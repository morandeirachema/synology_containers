#!/bin/bash
##################################################
# Synology Container Stack - Directory Setup
# Creates all required directories for services
##################################################

set -e

echo "🚀 Creating directories for Synology Container Stack..."

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base directories
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE_DIR"

echo -e "${BLUE}Working directory: $BASE_DIR${NC}"

# Create config directories
echo "📁 Creating configuration directories..."
mkdir -p config/{traefik/{dynamic,acme},authelia,wireguard,adguardhome/{work,conf},homeassistant,nodered,mosquitto,prometheus,grafana/provisioning/{datasources,dashboards}}

# Create data directories
echo "📁 Creating data directories..."
mkdir -p data/{vaultwarden,nextcloud,nextcloud-db,immich-postgres,paperless/{data,media},paperless-db,uptime-kuma,mosquitto/{data,log}}

# Create logs directory
echo "📁 Creating logs directory..."
mkdir -p logs/{traefik}

# Create backups directory
echo "📁 Creating backups directory..."
mkdir -p backups

# Set proper permissions for specific services
echo "🔐 Setting permissions..."

# Mosquitto requires specific UID/GID
if [ -d "data/mosquitto" ]; then
    chmod -R 755 data/mosquitto
fi

# Traefik ACME file needs specific permissions
if [ ! -f "config/traefik/acme/acme.json" ]; then
    mkdir -p config/traefik/acme
    touch config/traefik/acme/acme.json
    chmod 600 config/traefik/acme/acme.json
    echo -e "${GREEN}✓ Created acme.json with secure permissions${NC}"
fi

# Node-RED needs writable directory
if [ -d "config/nodered" ]; then
    chmod -R 755 config/nodered
fi

echo ""
echo -e "${GREEN}✅ Directory structure created successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Copy .env.example to .env and configure your settings"
echo "2. Review and update config files in config/ directory"
echo "3. For Mosquitto: Create password file with 'docker run -it --rm -v \$(pwd)/config/mosquitto:/mosquitto/config eclipse-mosquitto:latest mosquitto_passwd -c /mosquitto/config/passwd USERNAME'"
echo "4. Update domain names in Traefik and Authelia configs"
echo "5. Run: docker-compose up -d"
echo ""
