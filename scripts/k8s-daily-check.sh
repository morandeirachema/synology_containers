#!/bin/bash
#
# Kubernetes Daily Health Check Script
# Run this every morning to check cluster health
#
# Usage: ./k8s-daily-check.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
    fi
}

# Check if required commands exist
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v talosctl >/dev/null 2>&1 || { echo "talosctl is required but not installed. Aborting." >&2; exit 1; }

print_header "Kubernetes Daily Health Check - $(date)"

# 1. Node Status
print_header "1. Node Status"
kubectl get nodes -o wide

# Check if all nodes are Ready
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
print_status $NOT_READY "All nodes are Ready"

# 2. System Pods Health
print_header "2. System Pods Health"
echo "Checking kube-system namespace..."
KUBE_SYSTEM_NOT_RUNNING=$(kubectl get pods -n kube-system --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
print_status $KUBE_SYSTEM_NOT_RUNNING "All kube-system pods are Running"

echo "Checking monitoring namespace..."
MONITORING_NOT_RUNNING=$(kubectl get pods -n monitoring --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
print_status $MONITORING_NOT_RUNNING "All monitoring pods are Running"

echo "Checking logging namespace..."
LOGGING_NOT_RUNNING=$(kubectl get pods -n logging --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
print_status $LOGGING_NOT_RUNNING "All logging pods are Running"

# Show any problematic pods
echo -e "\nProblematic Pods (if any):"
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null || echo "None"

# 3. Recent Events
print_header "3. Recent Cluster Events (Last 20)"
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# Count warnings and errors
WARNING_COUNT=$(kubectl get events --all-namespaces --field-selector type=Warning --no-headers 2>/dev/null | wc -l)
echo -e "\n${YELLOW}Warning events in last hour: $WARNING_COUNT${NC}"

# 4. Disk Usage
print_header "4. Disk Usage on Nodes"
echo "Control Plane (192.168.1.201):"
talosctl -n 192.168.1.201 df 2>/dev/null | grep -E "FILESYSTEM|/dev/nvme" || echo "Could not retrieve disk info"

echo -e "\nWorker (192.168.1.202):"
talosctl -n 192.168.1.202 df 2>/dev/null | grep -E "FILESYSTEM|/dev/nvme" || echo "Could not retrieve disk info"

# 5. Persistent Volume Claims
print_header "5. Persistent Volume Claims"
echo "Pending PVCs:"
PENDING_PVCS=$(kubectl get pvc -A | grep Pending | wc -l)
if [ $PENDING_PVCS -eq 0 ]; then
    echo -e "${GREEN}No pending PVCs${NC}"
else
    echo -e "${RED}$PENDING_PVCS PVCs are Pending:${NC}"
    kubectl get pvc -A | grep Pending
fi

echo -e "\nPVC Usage Summary:"
kubectl get pvc -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,SIZE:.spec.resources.requests.storage,STORAGECLASS:.spec.storageClassName" 2>/dev/null || echo "No PVCs found"

# 6. Certificate Status
print_header "6. Certificate Status"
CERT_COUNT=$(kubectl get certificates -A --no-headers 2>/dev/null | wc -l)
if [ $CERT_COUNT -eq 0 ]; then
    echo "No certificates managed by cert-manager yet"
else
    echo "Certificates:"
    kubectl get certificates -A

    # Check for non-ready certificates
    NOT_READY_CERTS=$(kubectl get certificates -A --no-headers | grep -v "True" | wc -l)
    print_status $NOT_READY_CERTS "All certificates are Ready"
fi

# 7. Resource Usage
print_header "7. Resource Usage"
echo "Top Pods by Memory:"
kubectl top pods -A --sort-by=memory 2>/dev/null | head -10 || echo "Metrics server not available"

echo -e "\nTop Pods by CPU:"
kubectl top pods -A --sort-by=cpu 2>/dev/null | head -10 || echo "Metrics server not available"

echo -e "\nNode Resource Usage:"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"

# 8. Backup Status (if Velero is installed)
print_header "8. Backup Status"
if command -v velero &> /dev/null; then
    echo "Last 5 Velero backups:"
    velero backup get 2>/dev/null | head -6 || echo "Velero not configured or no backups found"
else
    echo "Velero CLI not installed - skipping backup check"
fi

# 9. Talos Health
print_header "9. Talos Linux Health"
echo "Checking Talos health on all nodes..."
talosctl health --nodes 192.168.1.201,192.168.1.202 2>/dev/null || echo "Could not check Talos health"

# 10. Summary
print_header "10. Summary"
TOTAL_PODS=$(kubectl get pods -A --no-headers | wc -l)
RUNNING_PODS=$(kubectl get pods -A --field-selector=status.phase=Running --no-headers | wc -l)
NAMESPACES=$(kubectl get namespaces --no-headers | wc -l)
SERVICES=$(kubectl get svc -A --no-headers | wc -l)

echo "Cluster Statistics:"
echo "  • Total Namespaces: $NAMESPACES"
echo "  • Total Services: $SERVICES"
echo "  • Total Pods: $TOTAL_PODS"
echo "  • Running Pods: $RUNNING_PODS"
echo "  • Pod Success Rate: $(awk "BEGIN {printf \"%.1f\", ($RUNNING_PODS/$TOTAL_PODS)*100}")%"

# Health Score
ISSUES=0
[ $NOT_READY -gt 0 ] && ISSUES=$((ISSUES+1))
[ $KUBE_SYSTEM_NOT_RUNNING -gt 0 ] && ISSUES=$((ISSUES+1))
[ $MONITORING_NOT_RUNNING -gt 0 ] && ISSUES=$((ISSUES+1))
[ $LOGGING_NOT_RUNNING -gt 0 ] && ISSUES=$((ISSUES+1))
[ $PENDING_PVCS -gt 0 ] && ISSUES=$((ISSUES+1))

echo -e "\n${BLUE}Overall Health:${NC}"
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ Cluster is HEALTHY${NC}"
elif [ $ISSUES -le 2 ]; then
    echo -e "${YELLOW}⚠ Cluster has MINOR issues ($ISSUES items need attention)${NC}"
else
    echo -e "${RED}✗ Cluster has MAJOR issues ($ISSUES items need immediate attention)${NC}"
fi

echo -e "\n${BLUE}Health check completed at $(date)${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Exit with appropriate code
if [ $ISSUES -gt 2 ]; then
    exit 1
else
    exit 0
fi
