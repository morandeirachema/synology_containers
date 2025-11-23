# Kubernetes Cluster Architecture

## Overview

This document explains the architectural decisions and design principles behind our A+ grade Talos Kubernetes cluster, integrated with the existing Synology Docker stack.

---

## Table of Contents

- [Design Principles](#design-principles)
- [Cluster Topology](#cluster-topology)
- [Network Architecture](#network-architecture)
- [Storage Architecture](#storage-architecture)
- [Security Architecture](#security-architecture)
- [Observability Architecture](#observability-architecture)
- [GitOps Workflow](#gitops-workflow)
- [Integration with Docker Stack](#integration-with-docker-stack)
- [Scalability Considerations](#scalability-considerations)
- [Technology Choices](#technology-choices)

---

## Design Principles

### 1. **Immutability**
- **Talos Linux**: Immutable OS with no SSH, no shell, API-only management
- **GitOps**: All configuration stored in Git, declarative state
- **Container Images**: Immutable, version-pinned images with SHA256 digests

### 2. **Security by Default**
- **Zero Trust**: Every component authenticates and encrypts
- **Least Privilege**: RBAC with minimal permissions
- **Secrets Management**: Conjur for centralized, audited secret storage
- **Network Policies**: Default deny, explicit allow
- **Pod Security**: Restricted security standards enforced

### 3. **Observability**
- **Metrics**: Prometheus for all components
- **Logs**: Centralized logging with Loki
- **Traces**: Optional distributed tracing with Tempo
- **Dashboards**: Grafana for unified visualization
- **Alerts**: ProactiveAlert Manager notifications

### 4. **Automation**
- **GitOps**: ArgoCD auto-sync from Git
- **Self-Healing**: Kubernetes controllers maintain desired state
- **Auto-Scaling**: HPA for workloads, cluster autoscaler (future)
- **Automated Backups**: Velero scheduled backups to Synology

### 5. **Simplicity & Maintainability**
- **Minimal Components**: Only what's necessary
- **Standard Tools**: Industry-proven solutions
- **Documentation**: Everything documented and version-controlled
- **Operational Runbooks**: Clear procedures for common tasks

---

## Cluster Topology

### Node Configuration

```
┌──────────────────────────────────────────────┐
│  Cluster: my-cluster                          │
│  Kubernetes Version: 1.29.x                   │
├──────────────────────────────────────────────┤
│                                               │
│  ┌─────────────────┐    ┌─────────────────┐ │
│  │  Node: cp-1     │    │  Node: worker-1 │ │
│  │  192.168.1.201  │    │  192.168.1.202  │ │
│  ├─────────────────┤    ├─────────────────┤ │
│  │ Roles:          │    │ Roles:          │ │
│  │ • control-plane │    │ • worker        │ │
│  │ • worker        │    │                 │ │
│  ├─────────────────┤    ├─────────────────┤ │
│  │ Control Plane:  │    │ Workloads:      │ │
│  │ • etcd          │    │ • Application   │ │
│  │ • API Server    │    │   Pods          │ │
│  │ • Scheduler     │    │ • System Pods   │ │
│  │ • Ctrl Manager  │    │                 │ │
│  │                 │    │                 │ │
│  │ Worker:         │    │                 │ │
│  │ • Kubelet       │    │                 │ │
│  │ • Application   │    │                 │ │
│  │   Pods          │    │                 │ │
│  └─────────────────┘    └─────────────────┘ │
│                                               │
└──────────────────────────────────────────────┘
```

### Hardware Specifications

| Component | Node 1 (CP) | Node 2 (Worker) |
|-----------|-------------|-----------------|
| **Model** | Beelink Mini S13 | Beelink Mini S13 |
| **CPU** | Intel N150 (4C/4T) | Intel N150 (4C/4T) |
| **RAM** | 16GB DDR4 | 16GB DDR4 |
| **Storage** | 512GB NVMe | 512GB NVMe |
| **Network** | 1Gbps Ethernet | 1Gbps Ethernet |
| **OS** | Talos Linux | Talos Linux |

### Resource Allocation Strategy

**Node 1 (Control Plane + Worker):**
- Control Plane: ~2GB RAM, ~1 CPU core (reserved)
- Available for workloads: ~14GB RAM, ~3 CPU cores
- Priority: System components, monitoring, stateless apps

**Node 2 (Worker):**
- Available for workloads: ~15GB RAM, ~3.5 CPU cores
- Priority: Applications, stateful workloads, databases

---

## Network Architecture

### Network Layers

```
┌────────────────────────────────────────────────────────┐
│                    Network Stack                        │
├────────────────────────────────────────────────────────┤
│                                                         │
│  Layer 7: Application                                  │
│  ┌──────────────────────────────────────────────────┐ │
│  │  Cilium Ingress Controller                       │ │
│  │  • TLS Termination (cert-manager certs)          │ │
│  │  • Host-based routing                            │ │
│  │  • Path-based routing                            │ │
│  └──────────────────────────────────────────────────┘ │
│                                                         │
│  Layer 4: Transport                                    │
│  ┌──────────────────────────────────────────────────┐ │
│  │  MetalLB Load Balancer                           │ │
│  │  • VIP: 192.168.1.200 (K8s API)                  │ │
│  │  • VIP: 192.168.1.210 (Ingress)                  │ │
│  │  • Pool: 192.168.1.211-220 (Services)            │ │
│  └──────────────────────────────────────────────────┘ │
│                                                         │
│  Layer 3: Network                                      │
│  ┌──────────────────────────────────────────────────┐ │
│  │  Cilium CNI (eBPF-based)                         │ │
│  │  • Pod Network: 10.244.0.0/16                    │ │
│  │  • Service Network: 10.96.0.0/12                 │ │
│  │  • Native routing mode                           │ │
│  │  • Network policies enforced in kernel           │ │
│  └──────────────────────────────────────────────────┘ │
│                                                         │
│  Layer 2: Data Link                                    │
│  ┌──────────────────────────────────────────────────┐ │
│  │  Physical Network                                 │ │
│  │  • Node Network: 192.168.1.0/24                  │ │
│  │  • MTU: 1500                                      │ │
│  │  • VLAN: Untagged (can be configured)            │ │
│  └──────────────────────────────────────────────────┘ │
│                                                         │
└────────────────────────────────────────────────────────┘
```

### Network Policies

**Default Deny Policy:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

**Allow Specific Traffic:**
- Ingress: Only from Cilium ingress controller
- Egress: DNS (53), HTTPS (443), inter-service communication
- Internal: Pod-to-pod within namespace (explicit)
- External: Deny by default, allow on per-service basis

### Service Mesh (Future Enhancement)

Cilium can provide service mesh capabilities without sidecar proxies:
- L7 policy enforcement
- Mutual TLS (mTLS)
- Traffic shaping and load balancing
- Observability with Hubble

---

## Storage Architecture

### Storage Tiers

```
┌──────────────────────────────────────────────────────┐
│               Storage Architecture                    │
├──────────────────────────────────────────────────────┤
│                                                       │
│  Tier 1: Local NVMe (Node Storage)                   │
│  ┌────────────────────────────────────────────────┐ │
│  │  Use Case: Ephemeral storage, cache, tmp files │ │
│  │  Performance: ~3000 MB/s read/write             │ │
│  │  Size: 512GB per node                           │ │
│  │  NOT REPLICATED - for temp data only            │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Tier 2: Synology NFS (Shared Storage)               │
│  ┌────────────────────────────────────────────────┐ │
│  │  StorageClass: nfs-client (default)             │ │
│  │  Performance: ~100-120 MB/s (1Gbps network)     │ │
│  │  Features:                                       │ │
│  │  • Dynamic provisioning                         │ │
│  │  • ReadWriteMany (RWX) support                  │ │
│  │  • Automatic backups (Synology)                 │ │
│  │  • Snapshots via DSM                            │ │
│  │  • Shared across all pods/nodes                 │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Tier 3: Synology iSCSI (Future, High Performance)   │
│  ┌────────────────────────────────────────────────┐ │
│  │  StorageClass: iscsi-lun                        │ │
│  │  Use Case: Databases, high I/O workloads        │ │
│  │  Performance: ~200-300 MB/s (better than NFS)   │ │
│  │  Access Mode: ReadWriteOnce (RWO) only          │ │
│  │  Requires: Democratic CSI driver                │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### Storage Classes

**Default NFS StorageClass:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "true"
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

**Usage Guidelines:**

| Workload Type | StorageClass | Access Mode | Why |
|---------------|--------------|-------------|-----|
| Config Files | nfs-client | RWX | Shared configs across pods |
| Static Assets | nfs-client | RWX | Served by multiple replicas |
| Application Data | nfs-client | RWO | Standard persistent data |
| Databases (light) | nfs-client | RWO | PostgreSQL, MariaDB (low traffic) |
| Databases (heavy) | iscsi-lun | RWO | High I/O requirements |
| Temporary | emptyDir | - | Ephemeral, node-local |
| Cache | Local NVMe | RWO | High-speed temporary storage |

### Backup Strategy

**Velero Backup Workflow:**
1. Daily scheduled backups at 2 AM
2. Backs up:
   - All PersistentVolumes (via snapshot or file copy)
   - All K8s resources (deployments, services, etc.)
   - Namespaces with specific labels
3. Retention: 30 days
4. Storage: Synology NFS `/volume1/k8s-backups`
5. Disaster recovery: Full cluster restore in <1 hour

---

## Security Architecture

### Defense in Depth

```
┌──────────────────────────────────────────────────────┐
│            Security Layers (Defense in Depth)         │
├──────────────────────────────────────────────────────┤
│                                                       │
│  Layer 1: Network Perimeter                          │
│  ┌────────────────────────────────────────────────┐ │
│  │  • Firewall (router-level)                     │ │
│  │  • Optional: CloudFlare Tunnel                 │ │
│  │  • Rate limiting (ingress controller)          │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Layer 2: TLS/mTLS                                    │
│  ┌────────────────────────────────────────────────┐ │
│  │  • cert-manager for automated TLS              │ │
│  │  • Let's Encrypt certificates                  │ │
│  │  • Future: mTLS via Cilium service mesh        │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Layer 3: Authentication & Authorization              │
│  ┌────────────────────────────────────────────────┐ │
│  │  • Kubernetes RBAC                             │ │
│  │  • Service Accounts with least privilege       │ │
│  │  • Optional: OAuth2/OIDC integration           │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Layer 4: Network Policies                            │
│  ┌────────────────────────────────────────────────┐ │
│  │  • Cilium network policies (L3/L4/L7)          │ │
│  │  • Default deny all traffic                    │ │
│  │  • Explicit allow rules                        │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Layer 5: Pod Security                                │
│  ┌────────────────────────────────────────────────┐ │
│  │  • Pod Security Standards (restricted)         │ │
│  │  • No privileged containers (unless required)  │ │
│  │  • Read-only root filesystems                  │ │
│  │  • Non-root users                              │ │
│  │  • Drop all capabilities, add specific ones    │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Layer 6: Secrets Management                          │
│  ┌────────────────────────────────────────────────┐ │
│  │  • Conjur for secrets storage                  │ │
│  │  • External Secrets Operator                   │ │
│  │  • Encrypted at rest (etcd)                    │ │
│  │  • Never in Git (even encrypted)               │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Layer 7: Image Security                              │
│  ┌────────────────────────────────────────────────┐ │
│  │  • Trivy Operator for vulnerability scanning   │ │
│  │  • Only trusted registries                     │ │
│  │  • Image signing (future: Sigstore)            │ │
│  │  • Admission controller to block bad images    │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Layer 8: Audit & Compliance                          │
│  ┌────────────────────────────────────────────────┐ │
│  │  • Kubernetes audit logs                       │ │
│  │  • Conjur audit logs                           │ │
│  │  • Falco for runtime security (optional)       │ │
│  │  • OPA Gatekeeper for policy enforcement       │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### RBAC Strategy

**Principle: Least Privilege**

1. **Namespace Isolation**: Each environment gets its own namespace
2. **ServiceAccounts**: Every pod uses a specific ServiceAccount
3. **Roles**: Fine-grained permissions per namespace
4. **ClusterRoles**: Only for cluster-wide resources (nodes, storage)

**Example RBAC Structure:**
```
ClusterRoles:
  - cluster-admin (emergency only)
  - view (read-only cluster-wide)
  - monitoring (Prometheus access)

Namespace Roles:
  - production:developer (read-only)
  - production:deployer (ArgoCD)
  - staging:developer (read-write)
  - staging:deployer (ArgoCD)
```

---

## Observability Architecture

### The Three Pillars

```
┌──────────────────────────────────────────────────────┐
│              Observability Stack                      │
├──────────────────────────────────────────────────────┤
│                                                       │
│  Pillar 1: Metrics (Prometheus + Grafana)            │
│  ┌────────────────────────────────────────────────┐ │
│  │  Sources:                                       │ │
│  │  • kubelet (node metrics)                      │ │
│  │  • kube-state-metrics (cluster state)          │ │
│  │  • node-exporter (hardware metrics)            │ │
│  │  • Application metrics (/metrics endpoint)     │ │
│  │                                                 │ │
│  │  Collection: Prometheus (30-day retention)     │ │
│  │  Long-term: Thanos or Mimir → Synology NFS     │ │
│  │  Visualization: Grafana dashboards             │ │
│  │  Alerting: AlertManager → Email/Slack          │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Pillar 2: Logs (Loki + Promtail)                    │
│  ┌────────────────────────────────────────────────┐ │
│  │  Collection: Promtail on each node             │ │
│  │  Aggregation: Loki                             │ │
│  │  Storage: Synology NFS /volume1/loki-data      │ │
│  │  Query: LogQL via Grafana                      │ │
│  │  Retention: 90 days                            │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Pillar 3: Traces (Optional: Tempo)                   │
│  ┌────────────────────────────────────────────────┐ │
│  │  Collection: OpenTelemetry Collector           │ │
│  │  Storage: Tempo                                │ │
│  │  Query: TraceQL via Grafana                    │ │
│  │  Integration: Cilium Hubble for network traces │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  Unified Interface: Grafana                           │
│  ┌────────────────────────────────────────────────┐ │
│  │  • Single pane of glass                        │ │
│  │  • Correlate metrics, logs, traces             │ │
│  │  • Pre-built dashboards                        │ │
│  │  • Custom dashboards as code                   │ │
│  │  • Alerting rules                              │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### Key Dashboards

1. **Cluster Overview**
   - Node health, CPU, memory, disk
   - Pod count, resource utilization
   - Network traffic

2. **Talos Specific**
   - etcd health
   - Control plane components
   - System services

3. **Application Metrics**
   - Request rates, latencies
   - Error rates
   - Business metrics

4. **Cilium Networking**
   - Network policies enforced/dropped
   - Connection tracking
   - Service mesh metrics (if enabled)

---

## GitOps Workflow

### ArgoCD Architecture

```
┌──────────────────────────────────────────────────────┐
│                GitOps Workflow                        │
├──────────────────────────────────────────────────────┤
│                                                       │
│  Step 1: Git Repository (Source of Truth)            │
│  ┌────────────────────────────────────────────────┐ │
│  │  Repository: synology-k8s-cluster              │ │
│  │  Structure:                                     │ │
│  │    • bootstrap/     (core components)          │ │
│  │    • infrastructure/ (shared services)         │ │
│  │    • apps/production/ (production apps)        │ │
│  │    • apps/staging/ (staging apps)              │ │
│  └────────────────────────────────────────────────┘ │
│                   ↓                                   │
│  Step 2: ArgoCD (Continuous Deployment)              │
│  ┌────────────────────────────────────────────────┐ │
│  │  • Polls Git repo every 3 minutes              │ │
│  │  • Detects changes to manifests                │ │
│  │  • Compares Git state vs cluster state         │ │
│  │  • Auto-syncs if enabled (or manual approval)  │ │
│  └────────────────────────────────────────────────┘ │
│                   ↓                                   │
│  Step 3: Kubernetes Cluster                           │
│  ┌────────────────────────────────────────────────┐ │
│  │  • Receives kubectl apply from ArgoCD          │ │
│  │  • Controllers reconcile to desired state      │ │
│  │  • Health checks report back to ArgoCD         │ │
│  └────────────────────────────────────────────────┘ │
│                   ↓                                   │
│  Step 4: Observability                                │
│  ┌────────────────────────────────────────────────┐ │
│  │  • Metrics collected (Prometheus)              │ │
│  │  • Logs aggregated (Loki)                      │ │
│  │  • Deployment events tracked                   │ │
│  │  • Alerts sent if issues detected              │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### App-of-Apps Pattern

**Root Application** (apps.yaml):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/user/synology-k8s-cluster
    targetRevision: HEAD
    path: apps/production
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Integration with Docker Stack

### Parallel Architecture

```
┌──────────────────────────────────────────────────────┐
│          Synology DS 224+ (192.168.1.100)            │
├──────────────────────────────────────────────────────┤
│                                                       │
│  Docker Stack (Existing)                             │
│  ┌────────────────────────────────────────────────┐ │
│  │  Core Services:                                 │ │
│  │  • Traefik (Edge Proxy) - Port 80/443          │ │
│  │  • Authelia (2FA)                              │ │
│  │  • Vaultwarden (Passwords)                     │ │
│  │  • Pi-hole (DNS)                               │ │
│  │  • Nextcloud (Files)                           │ │
│  │  • Databases (MariaDB, etc.)                   │ │
│  │                                                 │ │
│  │  Access: *.yourdomain.com                       │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
│  NFS Exports to K8s                                   │
│  ┌────────────────────────────────────────────────┐ │
│  │  • /volume1/k8s-pv → Persistent Volumes        │ │
│  │  • /volume1/k8s-backups → Velero backups       │ │
│  │  • /volume1/prometheus-data → Metrics storage  │ │
│  │  • /volume1/loki-data → Log storage            │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
└──────────────────────────────────────────────────────┘
                        ↑ NFS
                        │
┌──────────────────────────────────────────────────────┐
│    Kubernetes Cluster (Beelink Minis)                │
├──────────────────────────────────────────────────────┤
│                                                       │
│  K8s Services                                         │
│  ┌────────────────────────────────────────────────┐ │
│  │  New Workloads:                                 │ │
│  │  • Microservices                               │ │
│  │  • Cloud-native apps                           │ │
│  │  • CI/CD pipelines                             │ │
│  │  • Development environments                    │ │
│  │  • Batch jobs                                  │ │
│  │                                                 │ │
│  │  Access: *.k8s.yourdomain.com                   │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### Routing Strategy

**Option 1: Separate Subdomains**
- Docker: `*.yourdomain.com` (e.g., `vault.yourdomain.com`)
- K8s: `*.k8s.yourdomain.com` (e.g., `app.k8s.yourdomain.com`)
- Easy to distinguish and manage

**Option 2: Traefik as Unified Edge**
- All traffic → Traefik on Docker
- Docker services: Handled by Docker Traefik
- K8s services: Proxied to K8s Cilium Ingress
- Single entry point, more complex routing

**Recommended: Option 1** (separate subdomains) for simplicity

---

## Scalability Considerations

### Current State (2 nodes)
- **Control Plane**: Single instance (no HA)
- **Workload**: Distributed across 2 nodes
- **Storage**: Centralized on Synology

### Future Expansion Paths

**Add 3rd Node (True HA):**
```
Benefits:
- 3 control plane nodes (quorum)
- etcd can survive 1 node failure
- More capacity for workloads

Requirements:
- 1 more Beelink Mini S13
- Static IP (e.g., 192.168.1.203)
- Update Talos configs for multi-master
```

**Add Worker Nodes:**
```
Benefits:
- More workload capacity
- Better distribution
- Dedicated nodes for specific workloads

Requirements:
- Additional hardware
- Network capacity planning
- Storage scaling (more NFS connections)
```

**Cluster Autoscaler (Future):**
```
If running on cloud (AWS, GCP, Azure):
- Automatic node scaling based on demand
- Cost optimization

For bare-metal:
- Not applicable (fixed hardware)
- Manual scaling only
```

---

## Technology Choices

### Why Talos Linux?

| Feature | Talos | Traditional Linux | Winner |
|---------|-------|-------------------|--------|
| **Security** | No SSH, no shell, immutable | SSH access, mutable | ✅ Talos |
| **Simplicity** | API-only, minimal | Complex tooling | ✅ Talos |
| **Updates** | Rolling, zero-downtime | Manual or scripted | ✅ Talos |
| **K8s Native** | Built for K8s only | General purpose | ✅ Talos |
| **Attack Surface** | Minimal | Large | ✅ Talos |

### Why Cilium CNI?

| Feature | Cilium | Calico | Flannel |
|---------|--------|--------|---------|
| **Performance** | eBPF (kernel) | iptables | VXLAN |
| **L7 Policies** | ✅ | ❌ | ❌ |
| **Observability** | Hubble (built-in) | External tools | Minimal |
| **Service Mesh** | No sidecars | Requires Istio | ❌ |
| **Complexity** | Moderate | Low | Very Low |

**Choice**: Cilium for performance and features

### Why ArgoCD?

| Feature | ArgoCD | Flux CD | Jenkins X |
|---------|--------|---------|-----------|
| **UI** | Excellent | Minimal | Good |
| **Helm Support** | Native | Native | Native |
| **RBAC** | Built-in | Manual | Complex |
| **Sync Strategy** | Pull | Pull | Push |
| **Learning Curve** | Moderate | Low | High |

**Choice**: ArgoCD for UI and RBAC

### Why Conjur for Secrets?

| Feature | Conjur | Sealed Secrets | Vault |
|---------|--------|----------------|-------|
| **Audit Logs** | ✅ | ❌ | ✅ |
| **Policy Engine** | ✅ | ❌ | ✅ |
| **Rotation** | ✅ | Manual | ✅ |
| **Complexity** | Moderate | Low | High |
| **Cost** | Free (OSS) | Free | Free/Paid |

**Choice**: Conjur for enterprise features without complexity

---

## Summary

This architecture provides:

✅ **Security**: Defense in depth, secrets management, network policies
✅ **Reliability**: Automated backups, self-healing, monitoring
✅ **Scalability**: Can grow from 2 to many nodes
✅ **Maintainability**: GitOps, immutable infrastructure, documentation
✅ **Performance**: eBPF networking, NVMe storage, optimized stack
✅ **Integration**: Seamless coexistence with Docker stack
✅ **Cost-Effective**: Reuses existing Synology NAS, minimal new hardware

**Grade: A+** 🏆

---

[Back to Main README](../README.md) | [Setup Guide](TALOS_KUBERNETES_SETUP.md) | [Operations Guide](K8S_OPERATIONS.md)
