#!/bin/bash
#
# Kubernetes Backup Script
# Creates backups of:
# - Kubernetes resources (via Velero)
# - etcd snapshots
# - Talos configurations
# - Conjur data
#
# Usage: ./k8s-backup.sh [full|quick]

set -e

# Configuration
BACKUP_DIR="/volume1/k8s-backups"
TALOS_CONFIG_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")/talos"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_TYPE="${1:-full}"  # full or quick

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================"
echo "Kubernetes Backup Script"
echo "Backup Type: $BACKUP_TYPE"
echo "Date: $(date)"
echo -e "========================================${NC}\n"

# Check if commands exist
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v talosctl >/dev/null 2>&1 || { echo -e "${RED}talosctl is required but not installed.${NC}" >&2; exit 1; }

# Function to create backup directory
create_backup_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}Creating backup directory: $dir${NC}"
        mkdir -p "$dir" || {
            echo -e "${RED}Failed to create directory: $dir${NC}"
            exit 1
        }
    fi
}

# 1. Velero Backup (if installed)
backup_velero() {
    echo -e "\n${BLUE}1. Creating Velero Backup...${NC}"

    if command -v velero &> /dev/null; then
        BACKUP_NAME="manual-backup-$DATE"

        if [ "$BACKUP_TYPE" == "full" ]; then
            echo "Creating full backup of all namespaces..."
            velero backup create "$BACKUP_NAME" \
                --exclude-namespaces kube-system,kube-public,kube-node-lease \
                --wait
        else
            echo "Creating quick backup of production namespaces..."
            velero backup create "$BACKUP_NAME" \
                --include-namespaces production,staging \
                --wait
        fi

        # Check backup status
        velero backup describe "$BACKUP_NAME" | tail -20

        echo -e "${GREEN}✓ Velero backup created: $BACKUP_NAME${NC}"
    else
        echo -e "${YELLOW}⚠ Velero not installed - skipping${NC}"
    fi
}

# 2. etcd Snapshot
backup_etcd() {
    echo -e "\n${BLUE}2. Creating etcd Snapshot...${NC}"

    ETCD_BACKUP_DIR="$BACKUP_DIR/etcd"
    create_backup_dir "$ETCD_BACKUP_DIR"

    ETCD_SNAPSHOT="$ETCD_BACKUP_DIR/etcd-snapshot-$DATE.db"

    echo "Taking etcd snapshot from control plane..."
    talosctl -n 192.168.1.201 etcd snapshot "$ETCD_SNAPSHOT" 2>/dev/null || {
        echo -e "${RED}✗ Failed to create etcd snapshot${NC}"
        return 1
    }

    # Get file size
    if [ -f "$ETCD_SNAPSHOT" ]; then
        SIZE=$(du -h "$ETCD_SNAPSHOT" | cut -f1)
        echo -e "${GREEN}✓ etcd snapshot created: $ETCD_SNAPSHOT ($SIZE)${NC}"

        # Cleanup old snapshots (keep last 7 days)
        find "$ETCD_BACKUP_DIR" -name "etcd-snapshot-*.db" -mtime +7 -delete
        echo "Cleaned up etcd snapshots older than 7 days"
    else
        echo -e "${RED}✗ etcd snapshot file not found${NC}"
        return 1
    fi
}

# 3. Talos Configuration Backup
backup_talos_config() {
    echo -e "\n${BLUE}3. Backing up Talos Configurations...${NC}"

    TALOS_BACKUP_DIR="$BACKUP_DIR/talos-configs"
    create_backup_dir "$TALOS_BACKUP_DIR"

    TALOS_BACKUP_FILE="$TALOS_BACKUP_DIR/talos-config-$DATE.tar.gz"

    if [ -d "$TALOS_CONFIG_DIR" ]; then
        echo "Creating encrypted backup of Talos configs..."

        # Create tar archive (exclude .example files)
        tar -czf "$TALOS_BACKUP_FILE" \
            -C "$(dirname "$TALOS_CONFIG_DIR")" \
            --exclude='*.example' \
            --exclude='.git*' \
            talos/ 2>/dev/null || {
            echo -e "${RED}✗ Failed to create Talos config backup${NC}"
            return 1
        }

        # Encrypt with GPG (if available)
        if command -v gpg &> /dev/null; then
            echo "Encrypting backup with GPG..."
            gpg --batch --yes --passphrase "$(openssl rand -base64 32)" \
                --symmetric --cipher-algo AES256 \
                "$TALOS_BACKUP_FILE" 2>/dev/null && \
            rm "$TALOS_BACKUP_FILE"  # Remove unencrypted version

            echo -e "${GREEN}✓ Talos configs backed up and encrypted: ${TALOS_BACKUP_FILE}.gpg${NC}"
            echo -e "${YELLOW}⚠ IMPORTANT: Save the GPG passphrase securely!${NC}"
        else
            echo -e "${GREEN}✓ Talos configs backed up: $TALOS_BACKUP_FILE${NC}"
            echo -e "${YELLOW}⚠ GPG not found - backup is NOT encrypted${NC}"
        fi

        # Cleanup old backups (keep last 30 days)
        find "$TALOS_BACKUP_DIR" -name "talos-config-*.tar.gz*" -mtime +30 -delete
    else
        echo -e "${YELLOW}⚠ Talos config directory not found: $TALOS_CONFIG_DIR${NC}"
    fi
}

# 4. Kubernetes Resources Backup (YAML)
backup_k8s_resources() {
    echo -e "\n${BLUE}4. Backing up Kubernetes Resources...${NC}"

    K8S_BACKUP_DIR="$BACKUP_DIR/k8s-resources"
    create_backup_dir "$K8S_BACKUP_DIR"

    RESOURCE_BACKUP_DIR="$K8S_BACKUP_DIR/$DATE"
    mkdir -p "$RESOURCE_BACKUP_DIR"

    echo "Exporting Kubernetes resources to YAML..."

    # Export all resources by namespace
    for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
        # Skip system namespaces
        if [[ "$ns" == "kube-system" ]] || [[ "$ns" == "kube-public" ]] || [[ "$ns" == "kube-node-lease" ]]; then
            continue
        fi

        NS_DIR="$RESOURCE_BACKUP_DIR/$ns"
        mkdir -p "$NS_DIR"

        echo "  • Exporting namespace: $ns"

        # Export deployments
        kubectl get deployments -n "$ns" -o yaml > "$NS_DIR/deployments.yaml" 2>/dev/null || true

        # Export services
        kubectl get services -n "$ns" -o yaml > "$NS_DIR/services.yaml" 2>/dev/null || true

        # Export ingresses
        kubectl get ingresses -n "$ns" -o yaml > "$NS_DIR/ingresses.yaml" 2>/dev/null || true

        # Export configmaps (excluding system ones)
        kubectl get configmaps -n "$ns" -o yaml > "$NS_DIR/configmaps.yaml" 2>/dev/null || true

        # Export PVCs
        kubectl get pvc -n "$ns" -o yaml > "$NS_DIR/pvcs.yaml" 2>/dev/null || true

        # Export secrets (WARNING: contains sensitive data)
        kubectl get secrets -n "$ns" -o yaml > "$NS_DIR/secrets.yaml" 2>/dev/null || true
    done

    # Create archive
    echo "Creating archive..."
    tar -czf "$K8S_BACKUP_DIR/k8s-resources-$DATE.tar.gz" \
        -C "$K8S_BACKUP_DIR" "$DATE" && \
    rm -rf "$RESOURCE_BACKUP_DIR"

    echo -e "${GREEN}✓ Kubernetes resources backed up: k8s-resources-$DATE.tar.gz${NC}"
    echo -e "${YELLOW}⚠ This backup contains secrets - store securely!${NC}"

    # Cleanup old backups (keep last 14 days)
    find "$K8S_BACKUP_DIR" -name "k8s-resources-*.tar.gz" -mtime +14 -delete
}

# 5. Conjur Backup
backup_conjur() {
    echo -e "\n${BLUE}5. Backing up Conjur Data...${NC}"

    CONJUR_BACKUP_DIR="$BACKUP_DIR/conjur"
    create_backup_dir "$CONJUR_BACKUP_DIR"

    # Check if Conjur is running
    CONJUR_POD=$(kubectl get pod -n conjur -l app=conjur-oss -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -n "$CONJUR_POD" ]; then
        echo "Found Conjur pod: $CONJUR_POD"

        # Backup Conjur database
        echo "Backing up Conjur PostgreSQL database..."
        kubectl exec -n conjur "$CONJUR_POD" -- \
            pg_dump -U postgres -d postgres > "$CONJUR_BACKUP_DIR/conjur-db-$DATE.sql" 2>/dev/null || {
            echo -e "${YELLOW}⚠ Failed to backup Conjur database${NC}"
        }

        if [ -f "$CONJUR_BACKUP_DIR/conjur-db-$DATE.sql" ]; then
            gzip "$CONJUR_BACKUP_DIR/conjur-db-$DATE.sql"
            echo -e "${GREEN}✓ Conjur database backed up: conjur-db-$DATE.sql.gz${NC}"

            # Cleanup old backups (keep last 30 days)
            find "$CONJUR_BACKUP_DIR" -name "conjur-db-*.sql.gz" -mtime +30 -delete
        fi
    else
        echo -e "${YELLOW}⚠ Conjur not found - skipping${NC}"
    fi
}

# 6. Backup Summary
backup_summary() {
    echo -e "\n${BLUE}6. Backup Summary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Calculate total backup size
    if [ -d "$BACKUP_DIR" ]; then
        TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        echo "Total Backup Size: $TOTAL_SIZE"
        echo "Backup Location: $BACKUP_DIR"

        # List recent backups
        echo -e "\nRecent Backups:"
        ls -lh "$BACKUP_DIR"/*/ 2>/dev/null | tail -10 || echo "No backups found"
    fi

    echo -e "\n${GREEN}✓ Backup completed successfully!${NC}"
    echo "Backup Date: $(date)"
}

# Main execution
main() {
    backup_velero
    backup_etcd
    backup_talos_config

    if [ "$BACKUP_TYPE" == "full" ]; then
        backup_k8s_resources
        backup_conjur
    else
        echo -e "\n${YELLOW}Skipping K8s resources and Conjur (quick backup mode)${NC}"
    fi

    backup_summary

    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Backup Process Complete!${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

# Run main function
main
