#!/bin/bash
##################################################
# Synology Container Stack - Update All Containers
# Safely updates all containers with backup
##################################################

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Synology Container Stack - Update${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}⚠️  Do not run this script as root${NC}"
   exit 1
fi

# Backup first
echo -e "${YELLOW}📦 Creating backup before update...${NC}"
./scripts/backup.sh

echo ""
echo -e "${BLUE}🔄 Starting update process...${NC}"
echo ""

# Pull new images
echo -e "${YELLOW}⬇️  Pulling latest images...${NC}"
docker-compose pull

echo ""
echo -e "${YELLOW}🔄 Recreating containers with new images...${NC}"
docker-compose up -d

echo ""
echo -e "${YELLOW}🧹 Cleaning up old images...${NC}"
docker image prune -f

echo ""
echo -e "${GREEN}✅ Update completed successfully!${NC}"
echo ""
echo "📊 Current container status:"
docker-compose ps

echo ""
echo "💡 Next steps:"
echo "  - Check logs for any errors: docker-compose logs -f"
echo "  - Verify all services are healthy in Portainer"
echo "  - Monitor Uptime Kuma for any service disruptions"
echo ""
