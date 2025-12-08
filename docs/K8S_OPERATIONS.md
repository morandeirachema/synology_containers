# Kubernetes Operations Guide (Day-2)

This guide covers daily operations, maintenance, upgrades, and troubleshooting for your Talos Kubernetes cluster running as VMs on Proxmox VE.

---

## Cluster Overview

| Component | IP Address | Description |
|-----------|------------|-------------|
| **Proxmox Hosts** | | |
| pve1 | `192.168.1.11` | Beelink #1 hypervisor |
| pve2 | `192.168.1.12` | Beelink #2 hypervisor |
| pve3 | `192.168.1.13` | Beelink #3 hypervisor |
| **Talos VMs** | | |
| talos-cp-1 (VM 100) | `192.168.1.21` | Control plane + worker |
| talos-worker-2 (VM 101) | `192.168.1.22` | Dedicated worker |
| talos-worker-3 (VM 102) | `192.168.1.23` | Dedicated worker |
| **Services** | | |
| K8s API VIP | `192.168.1.20` | Kubernetes API endpoint |
| Synology NAS | `192.168.1.5` | NFS storage, DNS (Pi-hole) |

---

## Table of Contents

- [Daily Operations](#daily-operations)
- [Weekly Maintenance](#weekly-maintenance)
- [Monthly Tasks](#monthly-tasks)
- [Proxmox VM Operations](#proxmox-vm-operations)
- [Upgrades](#upgrades)
- [Backup & Restore](#backup--restore)
- [Monitoring & Alerts](#monitoring--alerts)
- [Security Operations](#security-operations)
- [Capacity Planning](#capacity-planning)
- [Incident Response](#incident-response)
- [Troubleshooting](#troubleshooting)

---

## Daily Operations

### Morning Health Check (5 minutes)

```bash
#!/bin/bash
# Daily cluster health check script

echo "=== Cluster Health Check ==="
date

# 1. Check node status
echo -e "\n1. Node Status:"
kubectl get nodes -o wide

# 2. Check system pods
echo -e "\n2. System Pods Status:"
kubectl get pods -n kube-system --field-selector=status.phase!=Running
kubectl get pods -n monitoring --field-selector=status.phase!=Running
kubectl get pods -n logging --field-selector=status.phase!=Running

# 3. Check recent events
echo -e "\n3. Recent Cluster Events:"
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# 4. Check disk usage on nodes (VMs use /dev/vda)
echo -e "\n4. Disk Usage:"
talosctl -n 192.168.1.21,192.168.1.22,192.168.1.23 df | grep -E "FILESYSTEM|/dev/vda"

# 5. Check for pending PVCs
echo -e "\n5. Pending PVCs:"
kubectl get pvc -A | grep Pending

# 6. Check certificate expiry
echo -e "\n6. Certificate Expiry:"
kubectl get certificates -A

echo -e "\n=== Health Check Complete ==="
```

Save as `scripts/k8s-daily-check.sh` and run daily.

### Check Grafana Dashboards

Access Grafana and review:
1. **Kubernetes/Compute Resources/Cluster**: Overall cluster health
2. **Talos Dashboard**: Node-specific metrics
3. **Cilium Metrics**: Network performance
4. **Alerts**: Any firing alerts

### Review Logs (Loki)

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open browser to http://localhost:3000
# Navigate to Explore → Loki
# Query: {namespace="production"} |= "error"
```

---

## Weekly Maintenance

### Monday: Security Scan (15 minutes)

```bash
# 1. Check for image vulnerabilities
kubectl get vulnerabilityreports -A

# 2. Review Trivy operator findings
kubectl get configauditreports -A

# 3. Check for failed authentication attempts
talosctl logs apid -n 192.168.1.21 | grep -i "authentication failed"

# 4. Review Conjur audit logs
kubectl logs -n conjur -l app=conjur-oss --tail=100 | grep -i audit

# 5. Check network policies are active
kubectl get networkpolicies -A
```

### Wednesday: Update Check (10 minutes)

```bash
# 1. Check for Talos updates
talosctl version --nodes 192.168.1.21,192.168.1.22,192.168.1.23

# Visit https://github.com/siderolabs/talos/releases for new versions

# 2. Check for Kubernetes updates
kubectl version

# 3. Check for Helm chart updates
helm repo update
helm list -A

# For each chart:
helm search repo <chart-name> --versions | head -5

# 4. Check for container image updates (Diun)
kubectl logs -n kube-system -l app=diun --tail=50
```

### Friday: Backup Verification (20 minutes)

```bash
# 1. Check Velero backup status
velero backup get
velero backup describe <latest-backup>

# 2. Verify backups on Synology
ssh admin@192.168.1.5 "ls -lh /volume1/k8s-backups/ | tail -10"

# 3. Test restore (optional, monthly)
# See Backup & Restore section

# 4. Verify etcd health
talosctl etcd members -n 192.168.1.21
```

---

## Monthly Tasks

### First Monday: Updates & Upgrades (1-2 hours)

**1. Update Helm Charts**

```bash
# Update repos
helm repo update

# List outdated charts
helm list -A

# Upgrade charts one by one (test in staging first!)
helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values k8s/infrastructure/monitoring/values.yaml

# Monitor the upgrade
kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus -n monitoring
```

**2. Update Container Images**

```bash
# For deployments managed by ArgoCD, update Git repo
# For manual deployments:

kubectl set image deployment/my-app \
  my-app=myregistry/my-app:v2.0.0 \
  --record

kubectl rollout status deployment/my-app
```

### Mid-Month: Capacity Planning (30 minutes)

```bash
# 1. Node resource usage trends
kubectl top nodes

# 2. Pod resource usage
kubectl top pods -A --sort-by=memory | head -20
kubectl top pods -A --sort-by=cpu | head -20

# 3. Storage usage
kubectl get pvc -A -o custom-columns=\
"NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
SIZE:.spec.resources.requests.storage,\
USED:.status.capacity.storage"

# 4. Check Prometheus for trends
# Query in Grafana:
# node_filesystem_avail_bytes{mountpoint="/var/lib/kubelet"}
# container_memory_working_set_bytes
```

### End of Month: Audit & Cleanup (1 hour)

```bash
# 1. Remove old container images
talosctl -n 192.168.1.21,192.168.1.22,192.168.1.23 service containerd \
  --action=cleanup

# 2. Clean up unused PVs
kubectl get pv | grep Released

# 3. Remove old completed jobs
kubectl delete jobs --field-selector status.successful=1 -A

# 4. Clean up old pods
kubectl delete pods --field-selector status.phase=Succeeded -A
kubectl delete pods --field-selector status.phase=Failed -A

# 5. Review and remove unused secrets/configmaps
kubectl get secrets -A --sort-by='.metadata.creationTimestamp'
kubectl get configmaps -A --sort-by='.metadata.creationTimestamp'

# 6. Clean old Velero backups (older than 30 days)
velero backup delete --confirm \
  --selector 'created-before=30d'
```

---

## Proxmox VM Operations

Since Talos runs as VMs on Proxmox VE, you have additional management options.

### VM Status Check

```bash
# From any Proxmox host
ssh root@192.168.1.11  # or .12, .13

# List all VMs
qm list

# Check specific VM status
qm status 100  # talos-cp-1
qm status 101  # talos-worker-2
qm status 102  # talos-worker-3

# Check VM config
qm config 100

# Check VM resource usage
qm monitor 100
```

### VM Snapshots (Before Upgrades)

```bash
# Create snapshot before major changes
qm snapshot 100 pre-talos-upgrade --description "Before Talos v1.9.1 upgrade"
qm snapshot 101 pre-talos-upgrade --description "Before Talos v1.9.1 upgrade"
qm snapshot 102 pre-talos-upgrade --description "Before Talos v1.9.1 upgrade"

# List snapshots
qm listsnapshot 100

# Rollback if something goes wrong
qm rollback 100 pre-talos-upgrade

# Delete old snapshots (after verifying upgrade success)
qm delsnapshot 100 pre-talos-upgrade
```

### VM Console Access

```bash
# Access VM console (if Talos is unresponsive)
# From Proxmox web UI: Select VM → Console

# Or via CLI (requires noVNC or SPICE)
qm terminal 100
```

### VM Restart (Proxmox Level)

```bash
# Graceful reboot (preferred)
qm reboot 100

# Hard stop and start (use if graceful fails)
qm stop 100 && sleep 5 && qm start 100

# Reset (immediate restart, like pressing reset button)
qm reset 100
```

### VM Live Migration (Proxmox HA)

```bash
# Migrate VM to another host (online, no downtime)
qm migrate 100 pve2 --online

# Check migration status
qm list | grep 100

# HA will auto-migrate if a host fails
ha-manager status
```

### Proxmox Cluster Status

```bash
# Check cluster health
pvecm status

# Check HA status
ha-manager status

# View HA group configuration
ha-manager groupstatus

# Check quorum
pvecm expected 3
```

### VM Backup (Proxmox Level)

```bash
# Manual backup (in addition to Velero K8s backups)
vzdump 100 --storage nas-backup --mode snapshot --compress zstd
vzdump 101 --storage nas-backup --mode snapshot --compress zstd
vzdump 102 --storage nas-backup --mode snapshot --compress zstd

# Schedule backups via Proxmox UI or cron
# Datacenter → Backup → Add
```

### Resource Adjustment

```bash
# Increase VM memory (requires restart)
qm set 100 --memory 14336  # 14GB

# Increase CPU cores
qm set 100 --cores 4

# Hot-add disk (if supported)
qm set 100 --scsi1 local-lvm:20,format=qcow2

# Apply changes (restart VM)
qm reboot 100
```

---

## Upgrades

### Upgrading Talos Linux

Talos upgrades are rolling and zero-downtime.

**Pre-Upgrade (Proxmox Snapshots):**
```bash
# Create VM snapshots before upgrade (safety net)
qm snapshot 100 pre-upgrade --description "Before Talos upgrade"
qm snapshot 101 pre-upgrade --description "Before Talos upgrade"
qm snapshot 102 pre-upgrade --description "Before Talos upgrade"
```

**Upgrade Process:**
```bash
# 1. Check current version
talosctl version -n 192.168.1.21,192.168.1.22,192.168.1.23

# 2. Review release notes
# https://github.com/siderolabs/talos/releases/tag/v1.9.1

# 3. Upgrade workers first (test)
talosctl upgrade -n 192.168.1.22 \
  --image ghcr.io/siderolabs/installer:v1.9.1 \
  --preserve

# Wait and verify
kubectl get nodes -w

talosctl upgrade -n 192.168.1.23 \
  --image ghcr.io/siderolabs/installer:v1.9.1 \
  --preserve

# 4. Upgrade control plane last
talosctl upgrade -n 192.168.1.21 \
  --image ghcr.io/siderolabs/installer:v1.9.1 \
  --preserve

# 5. Verify cluster health
talosctl health -n 192.168.1.21,192.168.1.22,192.168.1.23
kubectl get nodes
```

**Rollback if needed:**
```bash
# Option 1: Talos rollback
talosctl upgrade -n 192.168.1.21 \
  --image ghcr.io/siderolabs/installer:v1.9.0 \
  --preserve

# Option 2: Proxmox VM snapshot rollback (faster)
qm rollback 100 pre-upgrade
qm rollback 101 pre-upgrade
qm rollback 102 pre-upgrade
```

### Upgrading Kubernetes

Talos handles Kubernetes upgrades automatically.

```bash
# 1. Check current version
kubectl version --short

# 2. Upgrade to new version (e.g., 1.29.0 → 1.29.3)
talosctl upgrade-k8s -n 192.168.1.21 --to 1.29.3

# This will:
# - Upgrade control plane components
# - Upgrade kubelet on all nodes
# - Drain and upgrade nodes one by one
# - Zero downtime

# 3. Monitor progress
kubectl get nodes -w

# 4. Verify
kubectl version
kubectl get nodes
```

**Important Notes:**
- Only upgrade one minor version at a time (1.28 → 1.29, not 1.28 → 1.30)
- Test in staging first
- Read Kubernetes release notes for breaking changes
- Backup before upgrading

### Upgrading Cilium CNI

```bash
# 1. Check current version
cilium version

# 2. Update Helm repo
helm repo update

# 3. Review new version
helm search repo cilium/cilium --versions | head -5

# 4. Upgrade
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --values k8s/bootstrap/cilium/values.yaml \
  --version 1.14.6

# 5. Verify connectivity
cilium connectivity test

# 6. Check network policies still work
kubectl get networkpolicies -A
```

---

## Backup & Restore

### Manual Backup

```bash
# 1. Trigger Velero backup
velero backup create manual-backup-$(date +%Y%m%d) \
  --include-namespaces production,staging \
  --wait

# 2. Check backup status
velero backup describe manual-backup-$(date +%Y%m%d)

# 3. Backup Talos configuration
cd /path/to/synology_containers/talos
tar czf talos-config-backup-$(date +%Y%m%d).tar.gz \
  controlplane.yaml worker.yaml talosconfig kubeconfig

# Encrypt and store securely
gpg -c talos-config-backup-$(date +%Y%m%d).tar.gz
mv talos-config-backup-$(date +%Y%m%d).tar.gz.gpg /secure/location/

# 4. Backup etcd (Talos does this automatically, but manual option)
talosctl etcd snapshot -n 192.168.1.21 \
  > etcd-snapshot-$(date +%Y%m%d).db

scp etcd-snapshot-$(date +%Y%m%d).db \
  admin@192.168.1.5:/volume1/k8s-backups/etcd/
```

### Restore from Backup

**Restore Application Namespace:**

```bash
# 1. Delete namespace (if it exists)
kubectl delete namespace production

# 2. Restore from Velero backup
velero restore create --from-backup manual-backup-20250125

# 3. Monitor restore
velero restore get
velero restore describe <restore-name>

# 4. Verify pods are running
kubectl get pods -n production
```

**Disaster Recovery (Complete Cluster Loss):**

```bash
# 1. Rebuild cluster from Talos configs
# Follow TALOS_KUBERNETES_SETUP.md steps 1-4

# 2. Reinstall Velero
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --values k8s/infrastructure/velero/values.yaml

# 3. Restore all namespaces
velero restore create full-cluster-restore \
  --from-backup <latest-backup-name>

# 4. Verify
kubectl get pods -A
```

---

## Monitoring & Alerts

### Key Metrics to Monitor

**Node Health:**
- CPU usage > 80% sustained
- Memory usage > 85%
- Disk usage > 80%
- Network errors

**Pod Health:**
- Crash loop backoff
- OOMKilled pods
- ImagePullBackOff
- Pending pods > 5 minutes

**Storage:**
- PVC capacity > 80%
- NFS server latency
- Failed volume mounts

**Network:**
- DNS failures
- Network policy drops
- Ingress errors

### Setting Up Alerts

Create `k8s/infrastructure/monitoring/alerts.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-alerts
  namespace: monitoring
data:
  custom-alerts.yaml: |
    groups:
      - name: cluster-health
        interval: 30s
        rules:
          - alert: NodeDiskPressure
            expr: kube_node_status_condition{condition="DiskPressure",status="true"} == 1
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "Node {{ $labels.node }} has disk pressure"

          - alert: PodCrashLooping
            expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"

          - alert: HighMemoryUsage
            expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.85
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "Node {{ $labels.instance }} memory usage > 85%"
```

Apply:
```bash
kubectl apply -f k8s/infrastructure/monitoring/alerts.yaml
kubectl rollout restart statefulset/prometheus-kube-prometheus-stack-prometheus -n monitoring
```

### Configure Notification Channels

**Email Notifications:**

Edit `k8s/infrastructure/monitoring/values.yaml`:

```yaml
alertmanager:
  config:
    global:
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: 'alerts@yourdomain.com'
      smtp_auth_username: 'your-email@gmail.com'
      smtp_auth_password: 'app-specific-password'

    route:
      receiver: 'email-notifications'
      group_by: ['alertname', 'cluster']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h

    receivers:
      - name: 'email-notifications'
        email_configs:
          - to: 'admin@yourdomain.com'
            headers:
              Subject: '[K8s Alert] {{ .GroupLabels.alertname }}'
```

---

## Security Operations

### Certificate Rotation

**Talos Certificates (Automatic):**
Talos handles certificate rotation automatically. Verify:

```bash
talosctl get certificates -n 192.168.1.21
```

**Kubernetes Certificates:**
```bash
# Check expiry
kubectl get certificates -A

# Force renewal (if using cert-manager)
cmctl renew <certificate-name> -n <namespace>
```

### Secrets Rotation

**Rotate Conjur Secrets:**

```bash
# 1. Port-forward to Conjur
kubectl port-forward -n conjur svc/conjur-oss 8080:80

# 2. Login
conjur login -i admin

# 3. Update secret
conjur variable set -i k8s-secrets/database/password \
  -v "$(openssl rand -base64 32)"

# 4. ExternalSecret will auto-sync within refreshInterval

# 5. Restart pods to pick up new secret
kubectl rollout restart deployment/my-app -n production
```

### RBAC Audit

```bash
# 1. List all cluster roles
kubectl get clusterroles

# 2. Check who can perform dangerous operations
kubectl auth can-i --list --as=system:serviceaccount:default:default

# 3. Review role bindings
kubectl get rolebindings -A
kubectl get clusterrolebindings

# 4. Check for overly permissive roles
kubectl get clusterroles -o json | \
  jq '.items[] | select(.rules[].verbs[] | contains("*"))'
```

---

## Capacity Planning

### When to Add Resources

**Add Memory when:**
- Node memory consistently > 75%
- Frequent OOMKilled pods
- Swap usage increasing (if enabled)

**Add CPU when:**
- Node CPU consistently > 70%
- Pods throttled frequently
- High latency in applications

**Add Storage when:**
- PVC usage > 70%
- Prometheus retention needs > 30 days
- Log volume increasing

**Add Nodes when:**
- Can't schedule new pods (Pending)
- Need better HA (3+ control planes)
- Want dedicated nodes for workload types

### Scaling Strategies

**Vertical Scaling (increase pod resources):**
```yaml
resources:
  requests:
    cpu: 500m      # Increase from 250m
    memory: 1Gi    # Increase from 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

**Horizontal Scaling (more pod replicas):**
```bash
kubectl scale deployment my-app --replicas=5
```

**Auto-scaling (HPA):**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

---

## Incident Response

### Pod Crash Loop

```bash
# 1. Identify crashing pod
kubectl get pods -A | grep -E 'CrashLoopBackOff|Error'

# 2. Check logs
kubectl logs <pod-name> -n <namespace> --previous

# 3. Describe pod for events
kubectl describe pod <pod-name> -n <namespace>

# 4. Common fixes:
# - Resource limits too low → Increase
# - Missing config → Check ConfigMap/Secret
# - Application bug → Check logs, fix code
# - Liveness probe failing → Adjust probe settings
```

### Node NotReady

```bash
# 1. Check node status
kubectl describe node <node-name>

# 2. Check Talos logs
talosctl logs -n <node-ip>  # .21, .22, or .23

# 3. Check kubelet
talosctl logs kubelet -n <node-ip>

# 4. Common fixes:
# - Disk full → Clean up
# - Network issue → Check Cilium
# - Kubelet crash → Restart service
talosctl service kubelet restart -n <node-ip>

# 5. If Talos is unresponsive, use Proxmox console
# Proxmox UI → Select VM → Console
# Or: qm terminal 100  (for VM 100)
```

### Storage Issues

```bash
# 1. Check PVC status
kubectl get pvc -A

# 2. Check NFS connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  ping 192.168.1.5

# 3. Check NFS provisioner
kubectl logs -n kube-system -l app=nfs-subdir-external-provisioner

# 4. Test NFS mount manually
talosctl -n 192.168.1.21 read /proc/mounts | grep nfs
```

---

## Troubleshooting

### Common Issues

**Issue: Pods can't pull images**

```bash
# Check image pull secrets
kubectl get secrets
kubectl describe pod <pod-name> | grep -A5 "Events:"

# Fix: Create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=password
```

**Issue: DNS resolution failing**

```bash
# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup kubernetes.default

# Check CoreDNS
kubectl logs -n kube-system -l k8s-app=kube-dns

# Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
```

**Issue: Ingress not working**

```bash
# Check ingress resource
kubectl get ingress -A
kubectl describe ingress <name> -n <namespace>

# Check Cilium ingress controller
kubectl logs -n kube-system -l app.kubernetes.io/name=cilium

# Verify LoadBalancer IP assigned
kubectl get svc -n kube-system | grep cilium-ingress
```

### Getting Help

**Collect Diagnostics:**

```bash
# Talos diagnostics (all 3 VMs)
talosctl support -n 192.168.1.21,192.168.1.22,192.168.1.23

# Kubernetes diagnostics
kubectl cluster-info dump > cluster-dump.txt

# Cilium diagnostics
cilium sysdump

# Proxmox diagnostics (from Proxmox host)
pvecm status
ha-manager status
qm list
```

**Community Resources:**
- Talos Slack: https://slack.dev.talos-systems.io/
- Kubernetes Slack: https://slack.k8s.io/
- Cilium Slack: https://cilium.io/slack

---

## Automation Scripts

See `scripts/` directory for:
- `k8s-daily-check.sh` - Daily health checks
- `k8s-backup.sh` - Manual backup trigger
- `k8s-update-check.sh` - Check for updates
- `k8s-cleanup.sh` - Clean old resources

---

---

[Back to Main README](../README.md) | [K8s Architecture](K8S_ARCHITECTURE.md) | [K8s Deployment](K8S_DEPLOYMENT.md)
