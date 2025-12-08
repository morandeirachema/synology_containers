# Pre-Deployment Checklist

This checklist ensures the homelab Kubernetes environment is production-ready before deployment.

## Infrastructure Prerequisites

### Proxmox VE Cluster
- [ ] All 3 Proxmox nodes (pve1, pve2, pve3) are online and healthy
- [ ] Cluster status shows no errors: `pvecm status`
- [ ] Shared NFS storage mounted on all nodes
- [ ] Talos ISO uploaded to local storage on each node

### Network Configuration
- [ ] VLAN/Network segment configured: `192.168.1.0/24`
- [ ] Static IPs reserved for:
  - [ ] Proxmox nodes: `192.168.1.11-13`
  - [ ] Talos VMs: `192.168.1.21-23`
  - [ ] K8s API VIP: `192.168.1.20`
  - [ ] MetalLB range: `192.168.1.210-220`
- [ ] DNS records configured for:
  - [ ] `*.k8s.yourdomain.com` (wildcard or individual services)
  - [ ] Internal DNS resolution working

### Synology NAS (192.168.1.5)
- [ ] NFS service enabled
- [ ] NFS exports configured with correct permissions
- [ ] Kubernetes storage directories created:
  - [ ] `/volume1/kubernetes/`
  - [ ] Subdirectories for each application
- [ ] NFS accessible from K8s network

## Talos Linux VMs

### VM Configuration
- [ ] 3 VMs created with correct resources:
  - [ ] 12GB RAM (no ballooning)
  - [ ] 3 vCPU cores (host type)
  - [ ] 100GB virtio-scsi disk
  - [ ] virtio network adapter
- [ ] VMs booted from Talos ISO
- [ ] Each VM has static IP configured

### Talos Cluster Bootstrap
- [ ] Machine secrets generated: `talosctl gen secrets`
- [ ] Control plane config applied to all nodes
- [ ] Cluster bootstrapped: `talosctl bootstrap`
- [ ] All nodes in `Ready` state: `kubectl get nodes`

## Kubernetes Configuration

### Core Components
- [ ] CNI (Cilium) deployed and healthy
- [ ] CoreDNS running: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
- [ ] MetalLB configured with IP pool
- [ ] NFS CSI driver installed: `kubectl get pods -n nfs-system`

### Storage Verification
```bash
# Verify NFS provisioner
kubectl get storageclass nfs-client
kubectl get pods -n nfs-system

# Test PVC creation
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
EOF

# Verify PVC bound
kubectl get pvc test-pvc

# Clean up
kubectl delete pvc test-pvc
```

### Namespace Creation
- [ ] Create required namespaces:
```bash
kubectl create namespace traefik
kubectl create namespace monitoring
kubectl create namespace nextcloud
kubectl create namespace vaultwarden
kubectl create namespace homepage
kubectl create namespace it-tools
kubectl create namespace authelia
```

## Secrets Configuration

### Required Secrets (per application)

#### Traefik
- [ ] Cloudflare API credentials configured:
```bash
# Copy example and fill in values
cp k8s/base/traefik/cloudflare-credentials.env.example \
   k8s/base/traefik/cloudflare-credentials.env
# Edit with actual credentials
```

#### Nextcloud
- [ ] `nextcloud-secrets` in nextcloud namespace:
  - [ ] `postgres-password`
  - [ ] `admin-password`
  - [ ] `smtp-password` (if email enabled)

#### Vaultwarden
- [ ] `vaultwarden-secrets` in vaultwarden namespace:
  - [ ] `admin-token`
  - [ ] `postgres-password`
  - [ ] `smtp-host`, `smtp-from`, `smtp-username`, `smtp-password`

#### Authelia
- [ ] `authelia-secrets` in authelia namespace:
  - [ ] `jwt-secret`
  - [ ] `session-secret`
  - [ ] `storage-encryption-key`
  - [ ] `smtp-password`
  - [ ] `postgres-password`

### Secret Verification
```bash
# Check secrets exist in each namespace
kubectl get secrets -n traefik
kubectl get secrets -n nextcloud
kubectl get secrets -n vaultwarden
kubectl get secrets -n authelia
```

## Application Deployment Order

Deploy in this order to resolve dependencies:

1. **Infrastructure Layer**
   ```bash
   kubectl apply -k k8s/base/traefik/
   ```
   - [ ] Traefik pods running
   - [ ] LoadBalancer IP assigned
   - [ ] ACME certificates obtained

2. **Database Layer**
   ```bash
   kubectl apply -f k8s/base/nextcloud/postgres.yaml
   kubectl apply -f k8s/base/vaultwarden/postgres.yaml
   ```
   - [ ] PostgreSQL pods running and healthy
   - [ ] PVCs bound to NFS

3. **Authentication Layer**
   ```bash
   kubectl apply -k k8s/base/authelia/
   ```
   - [ ] Authelia pods running
   - [ ] Health checks passing

4. **Application Layer**
   ```bash
   kubectl apply -k k8s/base/nextcloud/
   kubectl apply -k k8s/base/vaultwarden/
   kubectl apply -k k8s/base/homepage/
   kubectl apply -k k8s/base/it-tools/
   ```
   - [ ] All application pods running
   - [ ] Ingress routes configured
   - [ ] TLS certificates valid

## Post-Deployment Verification

### Health Checks
```bash
# Check all pods are running
kubectl get pods --all-namespaces | grep -v Running

# Check all PVCs are bound
kubectl get pvc --all-namespaces | grep -v Bound

# Check ingress routes
kubectl get ingress --all-namespaces
```

### Service Connectivity
- [ ] Homepage accessible: `https://home.k8s.yourdomain.com`
- [ ] Vaultwarden accessible: `https://vault.k8s.yourdomain.com`
- [ ] Nextcloud accessible: `https://cloud.k8s.yourdomain.com`
- [ ] IT-Tools accessible: `https://tools.k8s.yourdomain.com`
- [ ] Traefik dashboard accessible (if enabled)

### Certificate Validation
```bash
# Check certificate status
kubectl get certificates --all-namespaces

# Verify TLS on ingress
curl -v https://home.k8s.yourdomain.com 2>&1 | grep -i "SSL certificate"
```

### Database Connectivity
```bash
# Nextcloud PostgreSQL
kubectl exec -n nextcloud -it nextcloud-postgres-0 -- \
  pg_isready -U nextcloud

# Vaultwarden PostgreSQL
kubectl exec -n vaultwarden -it vaultwarden-postgres-0 -- \
  pg_isready -U vaultwarden
```

## Monitoring Setup (Optional)

### Prometheus/Grafana Stack
- [ ] Prometheus deployed and scraping metrics
- [ ] Grafana accessible with dashboards
- [ ] Alertmanager configured (if alerts needed)

### Logging
- [ ] Log aggregation configured (if using Loki/EFK)
- [ ] Application logs accessible

## Backup Verification

### Database Backups
- [ ] PostgreSQL backup strategy documented
- [ ] Backup jobs scheduled (if using CronJob)
- [ ] Test restore procedure

### Volume Backups
- [ ] NFS snapshot/backup configured
- [ ] Critical data identified for backup

## Security Checklist

### Network Policies
- [ ] Default deny policies considered
- [ ] Inter-namespace communication restricted as needed

### Pod Security
- [ ] Pod Security Standards enforced
- [ ] SecurityContext configured on all pods:
  - [ ] `runAsNonRoot: true`
  - [ ] `allowPrivilegeEscalation: false`
  - [ ] Capabilities dropped

### Secrets
- [ ] No plaintext secrets in Git
- [ ] All placeholder values (`YOUR_*`, `CHANGE_THIS`) replaced
- [ ] Secret rotation plan documented

## Troubleshooting Commands

```bash
# Pod issues
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# Storage issues
kubectl describe pvc <pvc-name> -n <namespace>

# Network issues
kubectl run debug --rm -it --image=nicolaka/netshoot -- bash

# DNS issues
kubectl run dns-test --rm -it --image=busybox:1.36 -- nslookup kubernetes

# Talos issues
talosctl -n 192.168.1.21 dmesg
talosctl -n 192.168.1.21 services
```

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Infrastructure | | | |
| Security Review | | | |
| Final Approval | | | |

---

[Back to Main README](../README.md) | [Talos Setup](TALOS_KUBERNETES_SETUP.md) | [Secrets Management](SECRETS_MANAGEMENT.md)
