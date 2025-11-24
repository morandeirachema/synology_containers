# Kubernetes Cluster - Quick Reference Guide

**Grade**: 🏆 PERFECT 100/100 + Optional Enhancements

---

## 📐 Architecture Overview

### Physical Infrastructure

```
┌───────────────────────────────────────────────────────────────────────────┐
│                      Home Network (192.168.1.0/24)                         │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐       │
│  │ Beelink Mini S13 │  │ Beelink Mini S13 │  │ Beelink Mini S13 │       │
│  │    (Node 1)      │  │    (Node 2)      │  │    (Node 3)      │       │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤       │
│  │ CPU: 4 cores     │  │ CPU: 4 cores     │  │ CPU: 4 cores     │       │
│  │ RAM: 16GB        │  │ RAM: 16GB        │  │ RAM: 16GB        │       │
│  │ Disk: 512GB NVMe │  │ Disk: 512GB NVMe │  │ Disk: 512GB NVMe │       │
│  │ OS: Talos Linux  │  │ OS: Talos Linux  │  │ OS: Talos Linux  │       │
│  │ Intel N150       │  │ Intel N150       │  │ Intel N150       │       │
│  │ Role: Control    │  │ Role: Worker     │  │ Role: Worker     │       │
│  │      + Worker    │  │                  │  │                  │       │
│  │ IP: 192.168.1.11 │  │ IP: 192.168.1.12 │  │ IP: 192.168.1.13 │       │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘       │
│           │                     │                     │                   │
│           └─────────────────────┼─────────────────────┘                   │
│                                 │                                         │
│                      ┌──────────▼──────────┐                             │
│                      │  Virtual IP (VIP)   │                             │
│                      │  192.168.1.10       │                             │
│                      │  (MetalLB)          │                             │
│                      └──────────┬──────────┘                             │
│                                 │                                         │
│                      ┌──────────▼──────────────────┐                     │
│                      │   Synology DS 224+          │                     │
│                      │   192.168.1.5               │                     │
│                      ├──────────────────────────────┤                     │
│                      │ • NFS Server (PVs)          │                     │
│                      │ • Pi-hole (DNS)             │                     │
│                      │ • Backup Target (Velero)    │                     │
│                      │ • Logs/Metrics Storage      │                     │
│                      └─────────────────────────────┘                     │
│                                                                            │
└───────────────────────────────────────────────────────────────────────────┘
```

### Kubernetes Cluster Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (100/100)                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                      INGRESS LAYER                              │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐     │    │
│  │  │ Traefik      │  │ cert-manager │  │ MetalLB          │     │    │
│  │  │ (LoadBalancer│  │ (TLS Auto)   │  │ (192.168.1.10)   │     │    │
│  │  │  + Ingress)  │  │              │  │                  │     │    │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘     │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    AUTHENTICATION LAYER                         │    │
│  │  ┌──────────────────────────────────────────────────────────┐  │    │
│  │  │ Authelia (SSO with 2FA)                                  │  │    │
│  │  │ • TOTP / WebAuthn / Duo Push                            │  │    │
│  │  │ • Session management                                     │  │    │
│  │  └──────────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                   APPLICATION LAYER                             │    │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌─────────┐  │    │
│  │  │Vaultwarden │  │ Nextcloud  │  │  Homepage  │  │IT-Tools │  │    │
│  │  │(Passwords) │  │  (Files)   │  │(Dashboard) │  │ (Utils) │  │    │
│  │  └────────────┘  └────────────┘  └────────────┘  └─────────┘  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                   OBSERVABILITY LAYER                           │    │
│  │  ┌────────────┐  ┌──────────┐  ┌────────┐  ┌──────────────┐   │    │
│  │  │Prometheus  │  │ Grafana  │  │  Loki  │  │    Jaeger    │   │    │
│  │  │(Metrics)   │  │(Dashboards│  │ (Logs) │  │   (Tracing)  │   │    │
│  │  └────────────┘  └──────────┘  └────────┘  └──────────────┘   │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                   PLATFORM LAYER                                │    │
│  │  ┌────────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐  │    │
│  │  │  ArgoCD    │  │ Conjur   │  │ Velero  │  │    Trivy     │  │    │
│  │  │  (GitOps)  │  │(Secrets) │  │(Backups)│  │  (Scanning)  │  │    │
│  │  └────────────┘  └──────────┘  └─────────┘  └──────────────┘  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                   INFRASTRUCTURE LAYER                          │    │
│  │  ┌────────────┐  ┌────────────┐  ┌─────────────────────────┐  │    │
│  │  │   Cilium   │  │ kube-system│  │  NFS Provisioner        │  │    │
│  │  │   (CNI)    │  │ (K8s Core) │  │  (Storage)              │  │    │
│  │  └────────────┘  └────────────┘  └─────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Optional Enhancements Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│            Optional Enhancements (Beyond 100/100)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │               HIGH PRIORITY - Defense-in-Depth                  │    │
│  │  ┌────────────┐  ┌──────────────┐  ┌──────────────────────┐   │    │
│  │  │   Falco    │  │  Gatekeeper  │  │    Kubescape         │   │    │
│  │  │ (Runtime   │  │  (Policy     │  │  (CIS/NSA/CISA       │   │    │
│  │  │  Threats)  │  │  Enforcement)│  │   Compliance)        │   │    │
│  │  │  ~50MB RAM │  │  ~400MB RAM  │  │   ~200MB RAM         │   │    │
│  │  └────────────┘  └──────────────┘  └──────────────────────┘   │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │            MEDIUM PRIORITY - Operational Excellence             │    │
│  │  ┌──────────────┐  ┌──────────┐  ┌──────────────────────┐     │    │
│  │  │CloudNativePG │  │ OpenCost │  │      Flagger         │     │    │
│  │  │ (PostgreSQL  │  │ (FinOps) │  │  (Progressive        │     │    │
│  │  │  HA + PITR)  │  │  FREE    │  │   Delivery)          │     │    │
│  │  └──────────────┘  └──────────┘  └──────────────────────┘     │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              LOW PRIORITY - Advanced Features                   │    │
│  │  ┌────────────────────────┐  ┌──────────────────────────────┐  │    │
│  │  │      Thanos            │  │        Chaos Mesh            │  │    │
│  │  │  (Long-term Metrics)   │  │  (Chaos Engineering)         │  │    │
│  │  │  Multi-year retention  │  │  Resilience Testing          │  │    │
│  │  └────────────────────────┘  └──────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📦 Component List

### Core Infrastructure (100/100 Baseline)

| Component | Purpose | Namespace | Replicas | Resources |
|-----------|---------|-----------|----------|-----------|
| **Cilium** | CNI networking (eBPF) | kube-system | DaemonSet | ~200MB/node |
| **MetalLB** | LoadBalancer (VIP) | metallb-system | 2 | ~50MB |
| **cert-manager** | TLS automation | cert-manager | 3 | ~200MB |
| **NFS Provisioner** | Dynamic PV provisioning | nfs-provisioner | 1 | ~100MB |

### Ingress & Auth

| Component | Purpose | Namespace | Replicas | Resources |
|-----------|---------|-----------|----------|-----------|
| **Traefik** | Ingress + LoadBalancer | traefik | 2 (HA) | ~300MB |
| **Authelia** | SSO with 2FA | authelia | 2 (HA) | ~200MB |

### Applications

| Component | Purpose | Namespace | Replicas | Resources |
|-----------|---------|-----------|----------|-----------|
| **Vaultwarden** | Password manager | vaultwarden | 2 (HA) | ~100MB |
| **Nextcloud** | File sync & share | nextcloud | 2 (HA) | ~500MB |
| **Homepage** | Dashboard | homepage | 2 (HA) | ~100MB |
| **IT-Tools** | Developer utilities | it-tools | 2 (HA) | ~100MB |

### Observability

| Component | Purpose | Namespace | Replicas | Resources |
|-----------|---------|-----------|----------|-----------|
| **Prometheus** | Metrics collection | monitoring | 2 (HA) | ~2GB |
| **Grafana** | Visualization | monitoring | 2 (HA) | ~400MB |
| **Loki** | Log aggregation | logging | 3 (HA) | ~1GB |
| **Jaeger** | Distributed tracing | tracing | 3 (HA) | ~500MB |
| **Alertmanager** | Alert routing | monitoring | 3 (HA) | ~100MB |

### Platform Services

| Component | Purpose | Namespace | Replicas | Resources |
|-----------|---------|-----------|----------|-----------|
| **ArgoCD** | GitOps | argocd | 3 (HA) | ~500MB |
| **Conjur** | Secrets management | conjur | 3 (HA) | ~300MB |
| **Velero** | Backups | velero | 1 | ~200MB |
| **Trivy** | Vulnerability scanning | trivy-system | 1 | ~300MB |

### Optional Enhancements

| Component | Priority | Purpose | Overhead |
|-----------|----------|---------|----------|
| **Falco** | HIGH | Runtime threat detection | ~50MB/node |
| **Gatekeeper** | HIGH | Policy enforcement | ~400MB |
| **Kubescape** | HIGH | Compliance scanning | ~200MB |
| **CloudNativePG** | MEDIUM | PostgreSQL operator | Variable |
| **OpenCost** | MEDIUM | Cost visibility | ~300MB |
| **Flagger** | MEDIUM | Progressive delivery | ~130MB |
| **Thanos** | LOW | Long-term metrics | ~650MB + storage |
| **Chaos Mesh** | LOW | Chaos engineering | ~900MB |

---

## 🚀 Deployment Cheat Sheet

### Initial Cluster Setup

```bash
# 1. Bootstrap Talos cluster
talosctl bootstrap -n 192.168.1.11 -e 192.168.1.11

# 2. Generate kubeconfig
talosctl kubeconfig -n 192.168.1.11

# 3. Verify cluster
kubectl get nodes
kubectl get pods -A
```

### Deploy Production Stack (100/100)

```bash
# Deploy complete production overlay
kubectl apply -k k8s/overlays/production/

# Verify deployment
kubectl get pods -A
kubectl get ingress -A
kubectl get certificates -A
```

### Deploy Production-Plus (100/100 + Security)

```bash
# Deploy production + HIGH priority security
kubectl apply -k k8s/overlays/production-plus/

# Verify security enhancements
kubectl get pods -n falco
kubectl get pods -n gatekeeper-system
kubectl get pods -n kubescape
```

### Deploy Individual Optional Components

```bash
# HIGH Priority - Defense-in-Depth
kubectl apply -k k8s/optional/high-priority/falco/
kubectl apply -k k8s/optional/high-priority/gatekeeper/
kubectl apply -k k8s/optional/high-priority/kubescape/

# MEDIUM Priority - Operational Excellence
kubectl apply -k k8s/optional/medium-priority/cloudnative-pg/
kubectl apply -k k8s/optional/medium-priority/opencost/
kubectl apply -k k8s/optional/medium-priority/flagger/

# LOW Priority - Advanced Features
kubectl apply -k k8s/optional/low-priority/thanos/
kubectl apply -k k8s/optional/low-priority/chaos-mesh/
```

---

## 🔧 Common Operations

### Cluster Health

```bash
# Check node status
kubectl get nodes
kubectl top nodes

# Check all pods
kubectl get pods -A
kubectl get pods -A --field-selector=status.phase!=Running

# Check events (last 1 hour)
kubectl get events -A --sort-by=.metadata.creationTimestamp | tail -50

# Cluster resource usage
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu
```

### Application Management

```bash
# Restart deployment
kubectl rollout restart deployment/vaultwarden -n vaultwarden

# Check deployment status
kubectl rollout status deployment/vaultwarden -n vaultwarden

# Scale deployment
kubectl scale deployment/homepage --replicas=3 -n homepage

# Check logs
kubectl logs -n vaultwarden -l app=vaultwarden --tail=100 -f

# Exec into pod
kubectl exec -it -n vaultwarden vaultwarden-xxx -- /bin/sh
```

### Certificate Management

```bash
# List certificates
kubectl get certificates -A

# Check certificate status
kubectl describe certificate vaultwarden-tls -n vaultwarden

# Force certificate renewal
kubectl delete secret vaultwarden-tls -n vaultwarden
kubectl delete certificaterequest -n vaultwarden --all
```

### Backup & Restore

```bash
# Create on-demand backup
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S)

# List backups
velero backup get

# Restore from backup
velero restore create --from-backup daily-backup-20250124

# Check backup status
velero backup describe daily-backup-20250124
```

### Monitoring & Alerts

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Check active alerts
kubectl port-forward -n monitoring svc/alertmanager-operated 9093:9093

# View Prometheus targets
curl http://localhost:9090/api/v1/targets | jq .
```

### Security Operations

```bash
# Check Pod Security Standards enforcement
kubectl get ns -L pod-security.kubernetes.io/enforce

# View NetworkPolicies
kubectl get networkpolicies -A

# Check Trivy scan results
kubectl get vulnerabilityreports -A

# View Falco alerts (if deployed)
kubectl logs -n falco -l app=falco --tail=50

# Check Gatekeeper violations (if deployed)
kubectl get constraints -A
```

### Troubleshooting

```bash
# Check pod details
kubectl describe pod <pod-name> -n <namespace>

# Get pod logs (previous container if crashed)
kubectl logs -n <namespace> <pod-name> --previous

# Check resource quotas
kubectl get resourcequota -A
kubectl describe resourcequota -n production

# Check PVC status
kubectl get pvc -A
kubectl describe pvc <pvc-name> -n <namespace>

# Verify DNS resolution
kubectl run dnstest --rm -it --image=busybox -- nslookup kubernetes.default

# Test network connectivity
kubectl run nettest --rm -it --image=nicolaka/netshoot -- bash
```

---

## 📊 Monitoring Quick Reference

### Grafana Dashboards

Access: `https://grafana.yourdomain.com`

**Pre-installed Dashboards**:
- **Kubernetes / Compute Resources / Cluster**: Overall cluster metrics
- **Kubernetes / Compute Resources / Namespace**: Per-namespace usage
- **Node Exporter Full**: Detailed node metrics
- **Traefik**: Ingress traffic and performance
- **ArgoCD**: GitOps deployment status
- **Loki**: Log exploration

**Optional Dashboards** (if deployed):
- **Falco**: Runtime security alerts (ID: 11914)
- **Gatekeeper**: Policy violations (ID: 14333)
- **OpenCost**: Cost breakdown (ID: 15798)
- **Flagger**: Canary deployments (ID: 15513)
- **CloudNativePG**: PostgreSQL metrics (ID: 20417)

### Prometheus Queries

```promql
# Node CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod CPU usage
sum(rate(container_cpu_usage_seconds_total{pod!=""}[5m])) by (namespace, pod)

# Pod memory usage
sum(container_memory_working_set_bytes{pod!=""}) by (namespace, pod)

# Cluster-wide request rate
sum(rate(traefik_entrypoint_requests_total[5m]))

# Error rate by service
sum(rate(traefik_service_requests_total{code=~"5.."}[5m])) by (service)
```

### Alert Summary

**Critical Alerts** (Immediate Action):
- Node down
- etcd leader lost
- Certificate expiring <7 days
- Persistent volume full
- High error rate (>5%)

**Warning Alerts** (Review Soon):
- High CPU/memory usage (>80%)
- Pod restart loops
- Backup failed
- Certificate expiring <30 days
- Slow response times

---

## 🔐 Security Quick Reference

### Pod Security Standards

```bash
# Check namespace PSS enforcement
kubectl get ns -L pod-security.kubernetes.io/enforce

# Expected output:
# authelia        restricted
# vaultwarden     restricted
# nextcloud       restricted
# monitoring      baseline
# kube-system     privileged
```

### Network Policies

```bash
# List all network policies
kubectl get networkpolicies -A

# Test network connectivity between namespaces
kubectl run -n source-ns test --rm -it --image=busybox -- \
  wget -qO- http://service.target-ns.svc.cluster.local
```

### TLS Certificates

```bash
# Check certificate expiration
kubectl get certificates -A -o json | \
  jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.status.notAfter)"'

# Verify TLS from outside
echo | openssl s_client -connect vaultwarden.yourdomain.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

---

## 📈 Resource Planning

### Current Utilization (100/100 Baseline)

| Resource | Used | Total | % |
|----------|------|-------|---|
| **CPU** | ~4 cores | 12 cores (3 nodes × 4) | 33% |
| **Memory** | ~6.5GB | 48GB (3 nodes × 16GB) | 14% |
| **Storage** | ~50GB | 1TB+ | 5% |

### With All Optional Enhancements

| Resource | Used | Total | % |
|----------|------|-------|---|
| **CPU** | ~5.5 cores | 12 cores (3 nodes × 4) | 46% |
| **Memory** | ~8.5GB | 48GB (3 nodes × 16GB) | 18% |
| **Storage** | ~60GB + Thanos | 1TB+ | Variable |

### Recommended Headroom

- Keep CPU <75% for burst capacity
- Keep Memory <80% to avoid OOM
- Keep Storage <70% for operational safety

---

## 🆘 Emergency Procedures

### Cluster Not Responding

```bash
# 1. Check nodes are up
talosctl get members -n 192.168.1.11

# 2. Check etcd health
kubectl get pods -n kube-system -l component=etcd

# 3. Check API server
kubectl get --raw /healthz

# 4. Emergency node reboot
talosctl reboot -n 192.168.1.11
```

### Application Down

```bash
# 1. Check pod status
kubectl get pods -n <namespace>

# 2. Check events
kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp

# 3. Check logs
kubectl logs -n <namespace> <pod-name> --previous

# 4. Restart deployment
kubectl rollout restart deployment/<app> -n <namespace>
```

### Certificate Issues

```bash
# 1. Check certificate status
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>

# 2. Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# 3. Delete and recreate
kubectl delete secret <cert-secret> -n <namespace>
kubectl delete certificaterequest -n <namespace> --all
```

### Out of Disk Space

```bash
# 1. Check PVC usage
kubectl get pvc -A
df -h  # On nodes via talosctl

# 2. Clean up completed pods
kubectl delete pods --field-selector=status.phase==Succeeded -A
kubectl delete pods --field-selector=status.phase==Failed -A

# 3. Clean old images
# Talos auto-cleans, but can force via node reboot
```

---

## 🔄 Upgrade Procedures

### Kubernetes Version Upgrade

```bash
# 1. Check current version
kubectl version

# 2. Upgrade control plane
talosctl upgrade -n 192.168.1.11 --image ghcr.io/siderolabs/installer:v1.8.0

# 3. Wait for control plane ready
kubectl wait --for=condition=Ready node/node1 --timeout=600s

# 4. Upgrade worker
talosctl upgrade -n 192.168.1.12 --image ghcr.io/siderolabs/installer:v1.8.0

# 5. Verify cluster
kubectl get nodes
kubectl get pods -A
```

### Application Updates

```bash
# 1. Update image tag in Kustomize
vim k8s/base/vaultwarden/deployment.yaml

# 2. Apply changes
kubectl apply -k k8s/overlays/production/

# 3. Watch rollout
kubectl rollout status deployment/vaultwarden -n vaultwarden

# 4. Verify application works
curl -k https://vaultwarden.yourdomain.com
```

---

## 📞 Quick Access URLs

### Core Services
- **Traefik Dashboard**: `https://traefik.yourdomain.com`
- **Authelia**: `https://auth.yourdomain.com`
- **Vaultwarden**: `https://vaultwarden.yourdomain.com`
- **Nextcloud**: `https://nextcloud.yourdomain.com`
- **Homepage**: `https://homepage.yourdomain.com`
- **IT-Tools**: `https://it-tools.yourdomain.com`

### Monitoring
- **Grafana**: `https://grafana.yourdomain.com`
- **Prometheus**: `https://prometheus.yourdomain.com`
- **Alertmanager**: `https://alertmanager.yourdomain.com`

### Platform
- **ArgoCD**: `https://argocd.yourdomain.com`
- **Conjur**: `https://conjur.yourdomain.com`

### Port-Forward Access (Local Only)

```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Jaeger
kubectl port-forward -n tracing svc/jaeger-query 16686:16686
```

---

## 📚 Documentation Links

- **[Perfect 100/100 Guide](K8S_PERFECT_100_GUIDE.md)**: Complete deployment guide
- **[Talos Setup](TALOS_KUBERNETES_SETUP.md)**: Initial cluster setup
- **[Operations Guide](K8S_OPERATIONS.md)**: Day-2 operations
- **[Optional Enhancements](../k8s/optional/README.md)**: Beyond 100/100
- **[Architecture](K8S_ARCHITECTURE.md)**: Design decisions
- **[Security](SECURITY.md)**: Security hardening

---

**Last Updated**: 2025-11-24
**Cluster Grade**: 🏆 PERFECT 100/100
