#!/bin/bash
##################################################
# Synology Container Stack - Health Check
# Monitors the health of all services
##################################################

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Synology Container Stack - Health Check${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

# Function to check container health
check_container() {
    local container=$1
    local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)

    if [ "$status" = "running" ]; then
        if [ "$health" = "healthy" ] || [ "$health" = "<no value>" ]; then
            echo -e "${GREEN}✅${NC} $container: Running"
        else
            echo -e "${YELLOW}⚠️${NC}  $container: Running but unhealthy ($health)"
        fi
    else
        echo -e "${RED}❌${NC} $container: Not running ($status)"
    fi
}

# Check all containers
echo "📊 Container Status:"
echo ""

containers=(
    "traefik"
    "authelia"
    "wireguard"
    "vaultwarden"
    "adguardhome"
    "homeassistant"
    "nodered"
    "mosquitto"
    "nextcloud"
    "nextcloud-db"
    "immich-server"
    "immich-postgres"
    "immich-redis"
    "paperless-ngx"
    "paperless-db"
    "paperless-redis"
    "portainer"
    "uptime-kuma"
    "grafana"
    "prometheus"
)

for container in "${containers[@]}"; do
    check_container "$container"
done

echo ""
echo "💾 Disk Usage:"
docker system df

echo ""
echo "🐳 Docker Stats (press Ctrl+C to exit):"
echo ""
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"

echo ""
echo "📈 Resource Summary:"
TOTAL_MEM=$(docker stats --no-stream --format "{{.MemPerc}}" | sed 's/%//' | awk '{sum+=$1} END {print sum"%"}')
echo "Total Memory Usage: $TOTAL_MEM"

echo ""
echo "🔍 Recent Errors (last 100 lines):"
docker-compose logs --tail=100 | grep -i error | tail -10 || echo "No recent errors found"

echo ""
echo -e "${GREEN}Health check complete!${NC}"
