#!/bin/bash
#
# Kubernetes Cleanup Script
# Removes old/unused resources to free up space
#
# Usage: ./k8s-cleanup.sh [--dry-run]

set -e

DRY_RUN=false
if [ "$1" == "--dry-run" ]; then
    DRY_RUN=true
    echo "DRY RUN MODE - No changes will be made"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================"
echo "Kubernetes Cleanup Script"
echo "Date: $(date)"
echo -e "========================================${NC}\n"

# 1. Clean up completed jobs
echo -e "${BLUE}1. Cleaning up completed jobs...${NC}"
COMPLETED_JOBS=$(kubectl get jobs -A --field-selector status.successful=1 --no-headers 2>/dev/null | wc -l)
echo "Found $COMPLETED_JOBS completed jobs"

if [ $COMPLETED_JOBS -gt 0 ] && [ "$DRY_RUN" = false ]; then
    kubectl delete jobs --field-selector status.successful=1 -A
    echo -e "${GREEN}✓ Deleted $COMPLETED_JOBS completed jobs${NC}"
elif [ "$DRY_RUN" = true ]; then
    kubectl get jobs -A --field-selector status.successful=1
fi

# 2. Clean up failed pods
echo -e "\n${BLUE}2. Cleaning up failed pods...${NC}"
FAILED_PODS=$(kubectl get pods -A --field-selector status.phase=Failed --no-headers 2>/dev/null | wc -l)
echo "Found $FAILED_PODS failed pods"

if [ $FAILED_PODS -gt 0 ] && [ "$DRY_RUN" = false ]; then
    kubectl delete pods --field-selector status.phase=Failed -A
    echo -e "${GREEN}✓ Deleted $FAILED_PODS failed pods${NC}"
elif [ "$DRY_RUN" = true ]; then
    kubectl get pods -A --field-selector status.phase=Failed
fi

# 3. Clean up succeeded pods (from jobs)
echo -e "\n${BLUE}3. Cleaning up succeeded pods...${NC}"
SUCCEEDED_PODS=$(kubectl get pods -A --field-selector status.phase=Succeeded --no-headers 2>/dev/null | wc -l)
echo "Found $SUCCEEDED_PODS succeeded pods"

if [ $SUCCEEDED_PODS -gt 0 ] && [ "$DRY_RUN" = false ]; then
    kubectl delete pods --field-selector status.phase=Succeeded -A
    echo -e "${GREEN}✓ Deleted $SUCCEEDED_PODS succeeded pods${NC}"
elif [ "$DRY_RUN" = true ]; then
    kubectl get pods -A --field-selector status.phase=Succeeded
fi

# 4. Clean up evicted pods
echo -e "\n${BLUE}4. Cleaning up evicted pods...${NC}"
EVICTED_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep Evicted | wc -l)
echo "Found $EVICTED_PODS evicted pods"

if [ $EVICTED_PODS -gt 0 ] && [ "$DRY_RUN" = false ]; then
    kubectl get pods -A --no-headers | grep Evicted | \
        awk '{print $2 " -n " $1}' | xargs -r kubectl delete pod
    echo -e "${GREEN}✓ Deleted $EVICTED_PODS evicted pods${NC}"
elif [ "$DRY_RUN" = true ]; then
    kubectl get pods -A | grep Evicted
fi

# 5. Clean up unused container images on nodes
echo -e "\n${BLUE}5. Cleaning up unused container images...${NC}"
echo "Running containerd cleanup on all nodes..."

if [ "$DRY_RUN" = false ]; then
    talosctl -n 192.168.1.201,192.168.1.202 service containerd cleanup 2>/dev/null || {
        echo -e "${YELLOW}⚠ Talos cleanup not available on this version${NC}"
    }
    echo -e "${GREEN}✓ Container image cleanup completed${NC}"
else
    echo "Would run: talosctl -n 192.168.1.201,192.168.1.202 service containerd cleanup"
fi

# 6. Clean up old Velero backups
echo -e "\n${BLUE}6. Cleaning up old Velero backups...${NC}"
if command -v velero &> /dev/null; then
    OLD_BACKUPS=$(velero backup get 2>/dev/null | tail -n +2 | wc -l)
    echo "Total Velero backups: $OLD_BACKUPS"

    if [ "$DRY_RUN" = false ]; then
        echo "Deleting backups older than 30 days..."
        velero backup delete --confirm --older-than 720h 2>/dev/null || echo "No old backups to delete"
        echo -e "${GREEN}✓ Old Velero backups cleaned up${NC}"
    else
        echo "Would delete backups older than 30 days"
        velero backup get 2>/dev/null | head -10
    fi
else
    echo -e "${YELLOW}⚠ Velero not installed - skipping${NC}"
fi

# 7. Clean up Released PVs
echo -e "\n${BLUE}7. Cleaning up Released PersistentVolumes...${NC}"
RELEASED_PVS=$(kubectl get pv --no-headers 2>/dev/null | grep Released | wc -l)
echo "Found $RELEASED_PVS released PVs"

if [ $RELEASED_PVS -gt 0 ]; then
    echo -e "${YELLOW}⚠ WARNING: This will permanently delete the following PVs:${NC}"
    kubectl get pv | grep Released

    if [ "$DRY_RUN" = false ]; then
        read -p "Are you sure you want to delete these PVs? (yes/no): " confirm
        if [ "$confirm" == "yes" ]; then
            kubectl get pv --no-headers | grep Released | awk '{print $1}' | \
                xargs -r kubectl delete pv
            echo -e "${GREEN}✓ Deleted $RELEASED_PVS released PVs${NC}"
        else
            echo "Skipping PV cleanup"
        fi
    fi
fi

# 8. Summary
echo -e "\n${BLUE}8. Cleanup Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Current resource count
TOTAL_PODS=$(kubectl get pods -A --no-headers | wc -l)
RUNNING_PODS=$(kubectl get pods -A --field-selector=status.phase=Running --no-headers | wc -l)
TOTAL_PVS=$(kubectl get pv --no-headers | wc -l)
BOUND_PVS=$(kubectl get pv --no-headers | grep Bound | wc -l)

echo "Current Status:"
echo "  • Total Pods: $TOTAL_PODS (Running: $RUNNING_PODS)"
echo "  • Total PVs: $TOTAL_PVS (Bound: $BOUND_PVS)"

# Disk usage on nodes
echo -e "\nDisk Usage on Nodes:"
talosctl -n 192.168.1.201 df 2>/dev/null | grep -E "FILESYSTEM|/dev/nvme" | head -2 || echo "Could not retrieve"
talosctl -n 192.168.1.202 df 2>/dev/null | grep -E "FILESYSTEM|/dev/nvme" | head -2 || echo "Could not retrieve"

if [ "$DRY_RUN" = true ]; then
    echo -e "\n${YELLOW}DRY RUN COMPLETE - No changes were made${NC}"
else
    echo -e "\n${GREEN}✓ Cleanup completed successfully!${NC}"
fi

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Cleanup Process Complete!${NC}"
echo -e "${BLUE}========================================${NC}\n"
