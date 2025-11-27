# Kubernetes Deployment Guide

This guide explains the deployment architecture for running your home stack on Kubernetes (Talos VMs on Proxmox) with only Pi-hole remaining on Docker.

---

## Cluster Overview

| Component | IP Address | Description |
|-----------|------------|-------------|
| **Proxmox Hosts** | | |
| pve1 | `192.168.1.11` | Beelink #1 (hosts VM 100) |
| pve2 | `192.168.1.12` | Beelink #2 (hosts VM 101) |
| pve3 | `192.168.1.13` | Beelink #3 (hosts VM 102) |
| **Talos VMs** | | |
| talos-cp-1 (VM 100) | `192.168.1.21` | Control plane + worker |
| talos-worker-2 (VM 101) | `192.168.1.22` | Dedicated worker |
| talos-worker-3 (VM 102) | `192.168.1.23` | Dedicated worker |
| **Services** | | |
| K8s API VIP | `192.168.1.20` | Kubernetes API endpoint |
| Synology NAS | `192.168.1.5` | NFS storage, DNS (Pi-hole) |
| MetalLB Pool | `192.168.1.210-220` | LoadBalancer service IPs |

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Why This Architecture](#why-this-architecture)
- [Deployment Strategy](#deployment-strategy)
- [Service Deployment](#service-deployment)
- [Pi-hole on Docker](#pi-hole-on-docker)
- [Accessing Services](#accessing-services)
- [Best Practices](#best-practices)

---

## Architecture Overview

### The Setup

```
┌───────────────────────────────────────────────────────────────────┐
│                         Your Network                              │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │             PROXMOX VE 8.x HA CLUSTER                        │ │
│  │  ┌─────────────────┐ ┌─────────────────┐ ┌───────────────┐  │ │
│  │  │  pve1 (.11)     │ │  pve2 (.12)     │ │  pve3 (.13)   │  │ │
│  │  │  Beelink #1     │ │  Beelink #2     │ │  Beelink #3   │  │ │
│  │  │  ─────────────  │ │  ─────────────  │ │  ───────────  │  │ │
│  │  │ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌───────────┐ │  │ │
│  │  │ │ VM 100      │ │ │ │ VM 101      │ │ │ │ VM 102    │ │  │ │
│  │  │ │ talos-cp-1  │ │ │ │ talos-      │ │ │ │ talos-    │ │  │ │
│  │  │ │ (.21)       │ │ │ │ worker-2    │ │ │ │ worker-3  │ │  │ │
│  │  │ │ CP + Worker │ │ │ │ (.22)       │ │ │ │ (.23)     │ │  │ │
│  │  │ └─────────────┘ │ │ └─────────────┘ │ │ └───────────┘ │  │ │
│  │  └─────────────────┘ └─────────────────┘ └───────────────┘  │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                               │                                   │
│                    K8s API VIP: 192.168.1.20                      │
│                               │                                   │
│  ┌────────────────────────────▼──────────────────────────────┐   │
│  │              Kubernetes Cluster (Talos VMs)                │   │
│  │                                                            │   │
│  │  Running Services:                                         │   │
│  │  - Traefik (Ingress)         - Prometheus + Grafana        │   │
│  │  - Authelia (SSO/2FA)        - Loki + Jaeger               │   │
│  │  - Vaultwarden (Passwords)   - ArgoCD (GitOps)             │   │
│  │  - Nextcloud (Files)         - Conjur (Secrets)            │   │
│  │  - Homepage (Dashboard)      - Velero (Backups)            │   │
│  │  - IT-Tools (Utilities)      - Trivy (Security)            │   │
│  └────────────────────────────┬──────────────────────────────┘   │
│                               │ NFS Storage + DNS                 │
│  ┌────────────────────────────▼──────────────────────────────┐   │
│  │              Synology DS 224+ (192.168.1.5)                │   │
│  │  ┌──────────────────────┐                                  │   │
│  │  │  Docker: Pi-hole     │  Also provides:                  │   │
│  │  │  - DNS + Ad Blocking │  - NFS storage for K8s PVs       │   │
│  │  │  - Port 53           │  - Backup target (Velero)        │   │
│  │  │  - Port 8053 (Admin) │  - Logs/metrics storage          │   │
│  │  └──────────────────────┘                                  │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

### Service Distribution

| Service | Platform | Reason |
|---------|----------|--------|
| **Pi-hole** | Docker (Synology) | DNS critical, avoid circular dependency |
| **Traefik** | Kubernetes | Ingress controller for all K8s services |
| **Authelia** | Kubernetes | SSO/2FA for K8s services |
| **Vaultwarden** | Kubernetes | Scalable, benefits from K8s features |
| **Nextcloud** | Kubernetes | Modern, cloud-native deployment |
| **Homepage** | Kubernetes | Perfect for K8s monitoring |
| **IT-Tools** | Kubernetes | Stateless, easy scaling |
| **Prometheus** | Kubernetes | K8s-native monitoring |
| **Grafana** | Kubernetes | Visualize K8s metrics |
| **Loki** | Kubernetes | K8s log aggregation |
| **ArgoCD** | Kubernetes | GitOps for K8s deployments |
| **Conjur** | Kubernetes | Enterprise secrets management |

---

## Why This Architecture?

### Why Only Pi-hole on Docker?

**DNS is Special:**

1. **Critical Dependency**: Your Kubernetes nodes need DNS to function. If Pi-hole is in K8s and the cluster has issues, you lose DNS → can't fix K8s (circular dependency).

2. **Network Stability**: DNS should be the most stable service. Docker on Synology is proven stable.

3. **Simplicity**: Pi-hole is simple and doesn't benefit from Kubernetes features (no scaling needed, no rolling updates required).

4. **Fallback**: If K8s cluster is down for maintenance, you still have DNS and can troubleshoot.

### Why Everything Else on Kubernetes?

**Modern Benefits:**

1. **Self-Healing**: Pods automatically restart on failure
2. **Scalability**: Easy horizontal scaling (add more replicas)
3. **Rolling Updates**: Zero-downtime deployments
4. **Resource Efficiency**: Better CPU/memory utilization
5. **Declarative**: Infrastructure as Code with GitOps
6. **Learning**: Hands-on experience with production K8s
7. **Future-Proof**: Cloud-native architecture
8. **Observability**: Built-in monitoring with Prometheus

---

## Deployment Strategy

### Phase 1: Infrastructure (Week 1)

**Deploy Core Components:**

```bash
# 1. Bootstrap Cilium CNI
kubectl apply -k k8s/bootstrap/cilium/

# 2. Deploy MetalLB for LoadBalancer
kubectl apply -k k8s/bootstrap/metallb/

# 3. Deploy cert-manager for TLS
kubectl apply -k k8s/bootstrap/cert-manager/

# 4. Deploy ArgoCD for GitOps
kubectl apply -k k8s/bootstrap/argocd/

# 5. Deploy NFS provisioner
kubectl apply -k k8s/infrastructure/nfs-provisioner/

# 6. Deploy Conjur for secrets
kubectl apply -k k8s/infrastructure/external-secrets/

# Verify infrastructure
kubectl get pods -A
```

### Phase 2: Monitoring (Week 1-2)

**Set Up Observability:**

```bash
# Deploy Prometheus + Grafana
kubectl apply -k k8s/infrastructure/monitoring/

# Deploy Loki + Promtail
kubectl apply -k k8s/infrastructure/logging/

# Deploy Velero for backups
kubectl apply -k k8s/infrastructure/velero/

# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80
# Open http://localhost:3000
```

### Phase 3: Ingress & Auth (Week 2)

**Deploy Edge Services:**

```bash
# Deploy Traefik ingress controller
kubectl apply -k k8s/base/traefik/

# Deploy Authelia SSO
kubectl apply -k k8s/base/authelia/

# Verify ingress is working
kubectl get svc -n traefik traefik
# Should show LoadBalancer IP (192.168.1.210)
```

### Phase 4: Applications (Week 2-3)

**Deploy User Services:**

```bash
# Option A: Deploy all production services
kubectl apply -k k8s/overlays/production/

# Option B: Deploy one at a time
kubectl apply -k k8s/base/homepage/
kubectl apply -k k8s/base/it-tools/
kubectl apply -k k8s/base/vaultwarden/
kubectl apply -k k8s/base/nextcloud/

# Verify deployments
kubectl get pods -n production
kubectl get ingress -A
```

### Phase 5: Monitoring & Tuning (Ongoing)

**Daily Operations:**

```bash
# Run daily health check
./scripts/k8s-daily-check.sh

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Review logs
kubectl logs -n production deployment/vaultwarden --tail=100

# Create backup
./scripts/k8s-backup.sh full
```

---

## Service Deployment

### Traefik (Ingress Controller)

**What it does:**
- Routes external traffic to K8s services
- Automatic HTTPS with Let's Encrypt
- Security headers and rate limiting
- Dashboard for monitoring

**Deploy:**

```bash
# 1. Create CloudFlare API secret
kubectl create secret generic cloudflare-api-credentials \
  -n traefik \
  --from-literal=email=admin@yourdomain.com \
  --from-literal=apiKey=YOUR_CLOUDFLARE_API_KEY

# 2. Deploy Traefik
kubectl apply -k k8s/base/traefik/

# 3. Verify LoadBalancer IP
kubectl get svc -n traefik traefik
# Note the EXTERNAL-IP (should be 192.168.1.210)

# 4. Update DNS
# Point *.yourdomain.com to 192.168.1.210 in CloudFlare
```

**Access:**
- Dashboard: https://traefik.yourdomain.com
- Metrics: http://192.168.1.210:9100/metrics

---

### Authelia (SSO & 2FA)

**What it does:**
- Single Sign-On for all services
- Two-Factor Authentication (TOTP, WebAuthn)
- Access control policies
- Session management

**Deploy:**

```bash
# 1. Generate secrets
mkdir -p k8s/base/authelia/secrets
openssl rand -base64 32 > k8s/base/authelia/secrets/jwt-secret.txt
openssl rand -base64 32 > k8s/base/authelia/secrets/session-secret.txt
openssl rand -base64 64 > k8s/base/authelia/secrets/storage-encryption-key.txt
echo "YOUR_SMTP_PASSWORD" > k8s/base/authelia/secrets/smtp-password.txt
openssl rand -base64 16 > k8s/base/authelia/secrets/postgres-password.txt

# 2. Update configuration
# Edit k8s/base/authelia/configmap.yaml
# - Update domain: yourdomain.com
# - Update SMTP settings
# - Add users to users_database.yml

# 3. Generate password hash
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'YOUR_PASSWORD'
# Copy hash to users_database.yml

# 4. Deploy Authelia
kubectl apply -k k8s/base/authelia/

# 5. Verify
kubectl get pods -n security
kubectl logs -n security deployment/authelia
```

**Access:** https://auth.yourdomain.com

**First Login:**
1. Navigate to https://auth.yourdomain.com
2. Login with credentials from `users_database.yml`
3. Set up 2FA (TOTP or WebAuthn)

---

### Vaultwarden (Password Manager)

**What it does:**
- Bitwarden-compatible password manager
- Store passwords, notes, cards
- Browser extensions, mobile apps
- WebSocket real-time sync

**Deploy:**

```bash
# 1. Update secrets
# Edit k8s/base/vaultwarden/kustomization.yaml
# - Set smtp-password
# - Set admin-token (for /admin panel)
# - Set postgres-password

# 2. Deploy Vaultwarden
kubectl apply -k k8s/base/vaultwarden/

# 3. Verify
kubectl get pods -n production -l app=vaultwarden
kubectl logs -n production statefulset/vaultwarden
```

**Access:** https://vault.yourdomain.com

**Setup:**
1. Create account (first user is admin if signups disabled)
2. Install browser extension or mobile app
3. Configure admin panel: https://vault.yourdomain.com/admin

---

### Nextcloud (File Storage)

**What it does:**
- File storage and sync (like Dropbox)
- Calendar, contacts, notes
- Collaborative editing
- Mobile and desktop apps

**Deploy:**

```bash
# 1. Update secrets
# Edit k8s/base/nextcloud/kustomization.yaml
# - Set postgres-password
# - Set admin-password

# 2. Deploy Nextcloud
kubectl apply -k k8s/base/nextcloud/

# 3. Wait for init (takes 2-3 minutes)
kubectl logs -n production statefulset/nextcloud -f

# 4. Verify
kubectl get pods -n production -l app=nextcloud
```

**Access:** https://cloud.yourdomain.com

**Post-Setup:**
1. Login with admin user
2. Install apps (Calendar, Contacts, Notes, etc.)
3. Configure external storage (optional)
4. Set up mobile/desktop sync clients

---

### Homepage (Dashboard)

**What it does:**
- Beautiful dashboard for all services
- Kubernetes cluster stats
- Service monitoring
- Customizable bookmarks

**Deploy:**

```bash
# 1. Customize dashboard
# Edit k8s/base/homepage/configmap.yaml
# - Update service URLs
# - Add/remove widgets
# - Customize bookmarks

# 2. Deploy Homepage
kubectl apply -k k8s/base/homepage/

# 3. Verify
kubectl get pods -l app=homepage
```

**Access:** https://home.yourdomain.com

---

### IT-Tools (Utilities)

**What it does:**
- Developer tools (base64, JSON formatter, UUID generator, etc.)
- No data storage (fully stateless)
- Fast and lightweight

**Deploy:**

```bash
kubectl apply -k k8s/base/it-tools/
```

**Access:** https://tools.yourdomain.com

---

## Pi-hole on Docker

### Why Keep Pi-hole on Docker?

See [Why Only Pi-hole on Docker?](#why-only-pi-hole-on-docker)

### Deployment

**docker-compose.yml** (Synology)

```yaml
version: '3.8'

services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    restart: unless-stopped
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "8053:80/tcp"  # Admin UI
    environment:
      TZ: 'America/New_York'
      WEBPASSWORD: 'your_secure_password'
      FTLCONF_LOCAL_IPV4: '192.168.1.5'  # Synology IP
      DNS1: '1.1.1.1'
      DNS2: '1.0.0.1'
    volumes:
      - '/volume1/docker/pihole/etc-pihole:/etc/pihole'
      - '/volume1/docker/pihole/etc-dnsmasq.d:/etc/dnsmasq.d'
    dns:
      - 127.0.0.1
      - 1.1.1.1
    networks:
      - docker-network
    cap_add:
      - NET_ADMIN
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  docker-network:
    name: docker-network
```

**Deploy:**

```bash
# On Synology
cd /volume1/docker
docker-compose up -d pihole
```

**Configure Kubernetes Nodes to Use Pi-hole:**

```bash
# Add to Talos machine config (all 3 VMs)
talosctl edit machineconfig -n 192.168.1.21,192.168.1.22,192.168.1.23

# Add under machine.network:
machine:
  network:
    nameservers:
      - 192.168.1.5  # Synology Pi-hole
      - 1.1.1.1      # Fallback
```

---

## Accessing Services

### Service URLs

| Service | URL | Protected by Authelia |
|---------|-----|----------------------|
| **Homepage** | https://home.yourdomain.com | Yes |
| **Traefik Dashboard** | https://traefik.yourdomain.com | Yes |
| **Authelia** | https://auth.yourdomain.com | No (login page) |
| **Grafana** | https://grafana.yourdomain.com | Yes |
| **Prometheus** | https://prometheus.yourdomain.com | Yes |
| **ArgoCD** | https://argocd.yourdomain.com | No (own auth) |
| **Vaultwarden** | https://vault.yourdomain.com | No (own auth) |
| **Nextcloud** | https://cloud.yourdomain.com | No (own auth) |
| **IT-Tools** | https://tools.yourdomain.com | Optional |
| **Conjur** | https://conjur.yourdomain.com | Yes |
| **Pi-hole** | http://192.168.1.5:8053 | No (own auth) |

### DNS Configuration

**CloudFlare DNS Records:**

```
Type  Name                  Content
A     yourdomain.com        192.168.1.210
A     *.yourdomain.com      192.168.1.210
```

**Or individual records:**

```
Type  Name                  Content
A     home                  192.168.1.210
A     traefik               192.168.1.210
A     auth                  192.168.1.210
A     vault                 192.168.1.210
A     cloud                 192.168.1.210
A     tools                 192.168.1.210
A     grafana               192.168.1.210
A     prometheus            192.168.1.210
A     argocd                192.168.1.210
```

---

## Best Practices

### 1. Use Kustomize Overlays

Keep base configurations clean and use overlays for environment-specific changes:

```bash
# Development
kubectl apply -k k8s/overlays/dev/

# Staging
kubectl apply -k k8s/overlays/staging/

# Production
kubectl apply -k k8s/overlays/production/
```

### 2. Pin Image Tags in Production

**Bad (in production):**
```yaml
images:
  - name: vaultwarden/server
    newTag: latest
```

**Good (in production):**
```yaml
images:
  - name: vaultwarden/server
    newTag: 1.30.5-alpine
```

### 3. Use External Secrets Operator

**Don't store secrets in Git:**
```yaml
# ❌ Bad
secretGenerator:
  - name: db-credentials
    literals:
      - password=supersecret123
```

**Use Conjur + ESO:**
```yaml
# ✅ Good
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  secretStoreRef:
    name: conjur
    kind: SecretStore
  data:
    - secretKey: password
      remoteRef:
        key: k8s-secrets/database/password
```

### 4. Enable Auto-Backup

```bash
# Daily backup cron job
0 2 * * * /home/user/synology_containers/scripts/k8s-backup.sh full

# Weekly cleanup
0 3 * * 0 /home/user/synology_containers/scripts/k8s-cleanup.sh
```

### 5. Monitor Everything

```bash
# Daily health check
./scripts/k8s-daily-check.sh

# Check Grafana dashboards daily
# - Kubernetes Cluster Overview
# - Node Resource Usage
# - Pod Resource Usage
# - Ingress Traffic
```

### 6. Document Custom Configurations

Keep a `CUSTOMIZATIONS.md` file documenting:
- Modified image tags
- Custom environment variables
- Resource limit adjustments
- Ingress customizations

### 7. Test Before Production

Always test in staging overlay first:

```bash
# Test in staging
kubectl apply -k k8s/overlays/staging/
# Verify functionality

# Promote to production
kubectl apply -k k8s/overlays/production/
```

---

## Troubleshooting

### Service Not Accessible

```bash
# Check ingress
kubectl get ingress -A
kubectl describe ingress <name> -n <namespace>

# Check certificate
kubectl get certificates -A
kubectl describe certificate <name> -n <namespace>

# Check Traefik logs
kubectl logs -n traefik deployment/traefik
```

### Pod Crashing

```bash
# Check pod status
kubectl get pods -A | grep -v Running

# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check previous logs (if restarted)
kubectl logs <pod-name> -n <namespace> --previous
```

### DNS Issues

```bash
# From Kubernetes node (any VM)
talosctl -n 192.168.1.21 shell
nslookup google.com
# Should resolve via Pi-hole (192.168.1.5)

# From pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- /bin/bash
nslookup google.com
```

### Storage Issues

```bash
# Check PVCs
kubectl get pvc -A

# Check PVs
kubectl get pv

# Check NFS provisioner
kubectl logs -n kube-system deployment/nfs-client-provisioner
```

---

## Next Steps

1. ✅ Deploy infrastructure (ArgoCD, Cilium, cert-manager, MetalLB)
2. ✅ Set up monitoring (Prometheus, Grafana, Loki)
3. ✅ Deploy Pi-hole on Synology Docker
4. ✅ Deploy Traefik and Authelia
5. ✅ Deploy applications (Vaultwarden, Nextcloud, Homepage)
6. ⏭️ Configure automated backups with Velero
7. ⏭️ Set up GitOps with ArgoCD
8. ⏭️ Enable Prometheus alerts
9. ⏭️ Document custom configurations
10. ⏭️ Profit! 🎉

---

[Back to Main README](../README.md) | [Setup Guide](TALOS_KUBERNETES_SETUP.md) | [Operations Guide](K8S_OPERATIONS.md) | [Architecture](K8S_ARCHITECTURE.md)
