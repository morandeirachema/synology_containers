# Talos Kubernetes Cluster Setup Guide

## Overview

This guide walks you through setting up a production-grade Kubernetes cluster using Talos Linux running as virtual machines on Proxmox VE. The cluster runs on 3x Beelink Mini S13 (Intel N150) devices, integrated with your Synology DS 224+ NAS for storage and observability.

**Cluster Specifications:**
- **Hypervisor**: Proxmox VE 9.x on each Beelink host
- **Control Plane**: 1x Talos VM (192.168.1.21 - hybrid control+worker)
- **Worker Nodes**: 2x Talos VMs (192.168.1.22, 192.168.1.23 - dedicated workers)
- **VM Resources**: 12GB RAM, 3 vCPU, 100GB disk per VM
- **Total K8s Resources**: 9 vCPU cores, 36GB RAM across 3 VMs
- **Storage**: Synology DS 224+ via NFS (192.168.1.5)
- **OS**: Talos Linux (immutable, API-managed Kubernetes OS)
- **Target Grade**: Perfect 100/100 Production

> **Prerequisites**: Before following this guide, complete the Proxmox setup on all nodes.
> See [PROXMOX_SETUP.md](./PROXMOX_SETUP.md) for detailed Proxmox installation and VM creation.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Phase 1: Preparation](#phase-1-preparation)
- [Phase 2: Talos Installation](#phase-2-talos-installation)
- [Phase 3: Kubernetes Bootstrap](#phase-3-kubernetes-bootstrap)
- [Phase 4: Core Infrastructure](#phase-4-core-infrastructure)
- [Phase 5: Storage Integration](#phase-5-storage-integration)
- [Phase 6: Observability Stack](#phase-6-observability-stack)
- [Phase 7: GitOps Setup](#phase-7-gitops-setup)
- [Phase 8: Security Hardening](#phase-8-security-hardening)
- [Phase 9: Backup & DR](#phase-9-backup--dr)
- [Verification & Testing](#verification--testing)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware Requirements

#### Physical Hardware (Proxmox Hosts)

| Component | Specification | Notes |
|-----------|--------------|-------|
| **Beelink Mini S13 #1** | Intel N150, 16GB RAM, 512GB NVMe | Proxmox host (192.168.1.11) |
| **Beelink Mini S13 #2** | Intel N150, 16GB RAM, 512GB NVMe | Proxmox host (192.168.1.12) |
| **Beelink Mini S13 #3** | Intel N150, 16GB RAM, 512GB NVMe | Proxmox host (192.168.1.13) |
| **Synology DS 224+** | 16GB RAM, Docker stack running | Storage + Observability |
| **Network Switch** | Gigabit Ethernet | All devices on same LAN |

#### Virtual Machine Specifications (Per Talos VM)

| Resource | Allocation | Notes |
|----------|------------|-------|
| **vCPUs** | 3 cores | CPU type: host |
| **RAM** | 12GB | Fixed allocation, no ballooning |
| **Disk** | 100GB | virtio-scsi, SSD emulation |
| **Network** | virtio on vmbr0 | Bridged to physical network |
| **Machine Type** | q35 | Modern chipset |
| **BIOS** | OVMF (UEFI) | Or SeaBIOS |

### Software Requirements

- **Operating System**: Windows, macOS, or Linux (for running tools)
- **Tools to Install**:
  - `talosctl` - Talos CLI tool
  - `kubectl` - Kubernetes CLI
  - `helm` - Kubernetes package manager
  - `argocd` CLI (optional)

### Network Requirements

- **Static IPs** assigned to all Proxmox hosts and Talos VMs
- **VIP (Virtual IP)** available for Kubernetes API (MetalLB)
- **DNS** resolution for cluster services (optional but recommended)
- **Firewall** rules allowing traffic between nodes
- **Proxmox bridge (vmbr0)** configured on each host

### Knowledge Requirements

- Intermediate Kubernetes knowledge
- Basic Linux command line skills
- Understanding of YAML
- Familiarity with Docker (helpful but not required)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Home Network (192.168.1.0/24)                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────┐ ┌─────────────────────────┐ ┌─────────────────────────┐
│  │   Beelink S13 #1        │ │   Beelink S13 #2        │ │   Beelink S13 #3        │
│  │   192.168.1.11          │ │   192.168.1.12          │ │   192.168.1.13          │
│  ├─────────────────────────┤ ├─────────────────────────┤ ├─────────────────────────┤
│  │     Proxmox VE 9.x      │ │     Proxmox VE 9.x      │ │     Proxmox VE 9.x      │
│  │  ┌───────────────────┐  │ │  ┌───────────────────┐  │ │  ┌───────────────────┐  │
│  │  │ Talos VM (100)    │  │ │  │ Talos VM (101)    │  │ │  │ Talos VM (102)    │  │
│  │  │ 192.168.1.21      │  │ │  │ 192.168.1.22      │  │ │  │ 192.168.1.23      │  │
│  │  │ 12GB/3vCPU/100GB  │  │ │  │ 12GB/3vCPU/100GB  │  │ │  │ 12GB/3vCPU/100GB  │  │
│  │  │ ───────────────── │  │ │  │ ───────────────── │  │ │  │ ───────────────── │  │
│  │  │ • Control Plane   │  │ │  │ • Worker Node     │  │ │  │ • Worker Node     │  │
│  │  │ • etcd            │  │ │  │ • Kubelet         │  │ │  │ • Kubelet         │  │
│  │  │ • API Server      │  │ │  │ • Container       │  │ │  │ • Container       │  │
│  │  │ • Scheduler       │  │ │  │   Runtime         │  │ │  │   Runtime         │  │
│  │  │ • Controller Mgr  │  │ │  │                   │  │ │  │                   │  │
│  │  │ • Kubelet (worker)│  │ │  │                   │  │ │  │                   │  │
│  │  └───────────────────┘  │ │  └───────────────────┘  │ │  └───────────────────┘  │
│  └───────────┬─────────────┘ └───────────┬─────────────┘ └───────────┬─────────────┘
│              │                           │                           │              │
│              └───────────────────────────┼───────────────────────────┘              │
│                                          │                                          │
│                             ┌────────────▼────────────┐                             │
│                             │  Kubernetes API VIP     │                             │
│                             │  192.168.1.20           │                             │
│                             │  (MetalLB managed)      │                             │
│                             └────────────┬────────────┘                             │
│                                          │                                          │
│  ┌───────────────────────────────────────▼───────────────────────────────────────┐ │
│  │                         Kubernetes Cluster                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │  Network Layer (Cilium CNI)                                             │  │ │
│  │  │  • Pod Network: 10.244.0.0/16    • Service Network: 10.96.0.0/12       │  │ │
│  │  │  • eBPF-based networking         • Built-in Ingress Controller         │  │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │  Core Services                    │  Observability Stack                │  │ │
│  │  │  • MetalLB (LoadBalancer)         │  • Prometheus (metrics)             │  │ │
│  │  │  • cert-manager (Certificates)    │  • Grafana (dashboards)             │  │ │
│  │  │  • ArgoCD (GitOps)                │  • Loki (logs)                      │  │ │
│  │  │  • External Secrets Operator      │  • Promtail (log shipping)          │  │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                          │                                          │
│                                          │ NFS                                      │
│                                          ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │  Synology DS 224+ NAS (192.168.1.5)                                           │ │
│  ├───────────────────────────────────────────────────────────────────────────────┤ │
│  │  Storage Services:                    │  Docker Stack:                        │ │
│  │  • /volume1/k8s-pv (NFS)             │  • Pi-hole (DNS)                      │ │
│  │  • /volume1/k8s-backups              │                                        │ │
│  │  • /volume1/proxmox-backup           │  Proxmox Storage:                      │ │
│  │  • /volume1/prometheus-data          │  • /volume1/proxmox-iso               │ │
│  │  • /volume1/loki-data                │  • VM backups via vzdump              │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Network IP Allocation

| Resource | IP Address | Purpose |
|----------|------------|---------|
| Proxmox Host 1 | 192.168.1.11 | Hypervisor management |
| Proxmox Host 2 | 192.168.1.12 | Hypervisor management |
| Proxmox Host 3 | 192.168.1.13 | Hypervisor management |
| Talos VM 1 | 192.168.1.21 | K8s control-plane + worker |
| Talos VM 2 | 192.168.1.22 | K8s worker |
| Talos VM 3 | 192.168.1.23 | K8s worker |
| Kubernetes API VIP | 192.168.1.20 | K8s API endpoint |
| MetalLB Pool | 192.168.1.210-220 | LoadBalancer services |
| Synology NAS | 192.168.1.5 | Storage + Docker |

---

## Phase 1: Preparation

### 1.1 Install Required Tools

#### Install talosctl

**macOS:**
```bash
brew install siderolabs/tap/talosctl
```

**Linux:**
```bash
curl -sL https://talos.dev/install | sh
```

**Windows (WSL2):**
```bash
curl -sL https://talos.dev/install | sh
```

**Verify installation:**
```bash
talosctl version
# Should show: Client: Tag: v1.6.0 (or later)
```

#### Install kubectl

**macOS:**
```bash
brew install kubectl
```

**Linux:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**Verify:**
```bash
kubectl version --client
```

#### Install Helm

**All Platforms:**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Verify:**
```bash
helm version
```

### 1.2 Prepare Synology NAS

#### Create NFS Shares

1. Log into Synology DSM
2. Open **Control Panel** → **Shared Folder**
3. Create shared folders:

| Folder Name | Path | Purpose |
|-------------|------|---------|
| `k8s-pv` | `/volume1/k8s-pv` | Kubernetes persistent volumes |
| `k8s-backups` | `/volume1/k8s-backups` | Velero backup storage |
| `k8s-registry` | `/volume1/k8s-registry` | Container image registry |
| `prometheus-data` | `/volume1/prometheus-data` | Long-term metrics storage |
| `loki-data` | `/volume1/loki-data` | Log storage |

4. Open **Control Panel** → **File Services** → **NFS**
5. Enable NFS service
6. For each folder, click **Edit** → **NFS Permissions**:
   - **Hostname or IP**: `192.168.1.21`, `192.168.1.22`, `192.168.1.23` (all Talos VMs)
   - **Privilege**: Read/Write
   - **Squash**: Map all users to admin
   - **Security**: sys (or krb5 if you want Kerberos)
   - **Enable asynchronous**: ☑ (check for better performance)
   - **Allow connections from non-privileged ports**: ☑ (check)
   - **Allow users to access mounted subfolders**: ☑ (check)

#### Test NFS Access

From your workstation (or one of the Beelink devices after Talos installation):
```bash
showmount -e 192.168.1.5
# Should show all exported NFS shares
```

### 1.3 Network Planning

IP allocations for Proxmox hosts and Talos VMs:

| Resource | IP Address | Purpose |
|----------|------------|---------|
| **Proxmox Hosts** | | |
| Proxmox Host 1 (pve1) | `192.168.1.11` | Hypervisor |
| Proxmox Host 2 (pve2) | `192.168.1.12` | Hypervisor |
| Proxmox Host 3 (pve3) | `192.168.1.13` | Hypervisor |
| **Talos VMs** | | |
| Talos VM 1 (Control Plane) | `192.168.1.21` | K8s control-plane + worker |
| Talos VM 2 (Worker) | `192.168.1.22` | K8s worker |
| Talos VM 3 (Worker) | `192.168.1.23` | K8s worker |
| **Kubernetes** | | |
| Kubernetes API VIP | `192.168.1.20` | MetalLB LoadBalancer for API |
| Ingress VIP | `192.168.1.210` | MetalLB LoadBalancer for Ingress |
| LoadBalancer Pool | `192.168.1.211-220` | MetalLB IP pool for services |

**Note**: Proxmox hosts are configured during Proxmox installation. Talos VM IPs are configured via Talos machine config.

---

## Phase 2: Talos Installation

> **Prerequisites**: Ensure Proxmox is installed on all 3 Beelink nodes and VMs are created.
> See [PROXMOX_SETUP.md](./PROXMOX_SETUP.md) for detailed instructions.

### 2.1 Verify Proxmox VMs

Ensure VMs are created on each Proxmox host:

| VM ID | Name | Host | Resources |
|-------|------|------|-----------|
| 100 | talos-cp-1 | pve1 | 12GB RAM, 3 vCPU, 100GB disk |
| 101 | talos-worker-2 | pve2 | 12GB RAM, 3 vCPU, 100GB disk |
| 102 | talos-worker-3 | pve3 | 12GB RAM, 3 vCPU, 100GB disk |

### 2.2 Boot Talos VMs

1. Start each VM from Proxmox web UI or CLI:
   ```bash
   # On each Proxmox host
   qm start 100  # On pve1
   qm start 101  # On pve2
   qm start 102  # On pve3
   ```

2. Open VM console via Proxmox web UI
3. Talos will boot from ISO into maintenance mode
4. Note the DHCP IP address displayed for each VM

**Verify connectivity:**
```bash
# From your workstation
ping <talos-vm-1-dhcp-ip>
ping <talos-vm-2-dhcp-ip>
ping <talos-vm-3-dhcp-ip>
```

### 2.3 Generate Talos Configuration

Create a directory for Talos configs:
```bash
cd /path/to/synology_containers
mkdir -p talos
cd talos
```

Generate cluster configuration (using new VM IP for API endpoint):
```bash
talosctl gen config my-cluster https://192.168.1.20:6443 \
  --output-dir .
```

This creates:
- `controlplane.yaml` - Control plane node configuration
- `worker.yaml` - Worker node configuration
- `talosconfig` - talosctl client configuration

### 2.4 Customize Configurations

#### Edit `controlplane.yaml`:

Add disk installation config (top of file, after `version`):
```yaml
machine:
  install:
    disk: /dev/vda  # virtio disk in Proxmox VM
    image: ghcr.io/siderolabs/installer:v1.9.0  # Use latest version
    wipe: false  # Set to true for clean install
```

Add network configuration (under `machine` → `network`):
```yaml
machine:
  network:
    hostname: talos-cp-1
    interfaces:
      - interface: eth0  # virtio-net adapter in Proxmox
        dhcp: false
        addresses:
          - 192.168.1.21/24  # VM IP (not host IP)
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.1.1
        vip:
          ip: 192.168.1.20  # Virtual IP for K8s API
    nameservers:
      - 192.168.1.5  # Pi-hole on Synology
      - 1.1.1.1
```

Add kubelet configuration (under `machine` → `kubelet`):
```yaml
machine:
  kubelet:
    extraArgs:
      rotate-server-certificates: "true"
    nodeIP:
      validSubnets:
        - 192.168.1.0/24
```

#### Edit `worker.yaml` (for talos-worker-2):

```yaml
machine:
  install:
    disk: /dev/vda  # virtio disk in Proxmox VM
    image: ghcr.io/siderolabs/installer:v1.9.0

  network:
    hostname: talos-worker-2
    interfaces:
      - interface: eth0  # virtio-net adapter
        dhcp: false
        addresses:
          - 192.168.1.22/24  # VM IP
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.1.1
    nameservers:
      - 192.168.1.5
      - 1.1.1.1

  kubelet:
    extraArgs:
      rotate-server-certificates: "true"
    nodeIP:
      validSubnets:
        - 192.168.1.0/24
```

#### Create `worker-3.yaml` (for talos-worker-3):

Copy `worker.yaml` and modify:
```yaml
machine:
  install:
    disk: /dev/vda
    image: ghcr.io/siderolabs/installer:v1.9.0

  network:
    hostname: talos-worker-3
    interfaces:
      - interface: eth0
        dhcp: false
        addresses:
          - 192.168.1.23/24  # Third worker VM IP
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.1.1
    nameservers:
      - 192.168.1.5
      - 1.1.1.1

  kubelet:
    extraArgs:
      rotate-server-certificates: "true"
    nodeIP:
      validSubnets:
        - 192.168.1.0/24
```

### 2.5 Apply Configurations and Install

**Apply config to control plane VM:**
```bash
talosctl apply-config --insecure \
  --nodes <talos-vm-1-dhcp-ip> \
  --file controlplane.yaml
```

**Wait for installation (2-5 minutes)**, then verify:
```bash
talosctl --nodes 192.168.1.21 --talosconfig=./talosconfig dashboard
```

**Apply config to worker VMs:**
```bash
# Worker 2
talosctl apply-config --insecure \
  --nodes <talos-vm-2-dhcp-ip> \
  --file worker.yaml

# Worker 3
talosctl apply-config --insecure \
  --nodes <talos-vm-3-dhcp-ip> \
  --file worker-3.yaml
```

**Configure talosctl to use the cluster:**
```bash
export TALOSCONFIG=$(pwd)/talosconfig
talosctl config endpoint 192.168.1.21
talosctl config node 192.168.1.21
```

Add to your shell profile (`~/.bashrc` or `~/.zshrc`):
```bash
export TALOSCONFIG=/path/to/synology_containers/talos/talosconfig
```

### 2.6 Post-Installation VM Configuration

After Talos is installed on all VMs:

1. **Remove ISO from VMs** (via Proxmox):
   ```bash
   # On each Proxmox host
   qm set 100 --ide2 none  # Remove CD/DVD
   qm set 100 --boot order=scsi0  # Boot from disk
   ```

2. **Add VMs to Proxmox HA** (optional but recommended):
   ```bash
   ha-manager add vm:100 --group talos-vms --state started
   ha-manager add vm:101 --group talos-vms --state started
   ha-manager add vm:102 --group talos-vms --state started
   ```

3. **Create initial VM snapshots**:
   ```bash
   qm snapshot 100 fresh-install --description "Fresh Talos install"
   qm snapshot 101 fresh-install --description "Fresh Talos install"
   qm snapshot 102 fresh-install --description "Fresh Talos install"
   ```

---

## Phase 3: Kubernetes Bootstrap

### 3.1 Bootstrap the Cluster

Bootstrap etcd and Kubernetes control plane:
```bash
talosctl bootstrap --nodes 192.168.1.21
```

Wait 3-5 minutes for bootstrap to complete.

### 3.2 Retrieve kubeconfig

```bash
talosctl kubeconfig .
# Creates kubeconfig file in current directory
```

Set up kubectl:
```bash
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

Expected output:
```
NAME            STATUS     ROLES           AGE   VERSION
talos-cp-1      Ready      control-plane   5m    v1.29.0
talos-worker-2  Ready      <none>          3m    v1.29.0
talos-worker-3  Ready      <none>          3m    v1.29.0
```

**Note**: Nodes may show `NotReady` initially until CNI is installed (next phase).

Add to your shell profile:
```bash
export KUBECONFIG=/path/to/synology_containers/talos/kubeconfig
```

### 3.3 Verify Cluster Health

```bash
# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check Talos health (all 3 VMs)
talosctl health --nodes 192.168.1.21,192.168.1.22,192.168.1.23
```

---

## Phase 4: Core Infrastructure

### 4.1 Install Cilium CNI

Cilium is a modern CNI that uses eBPF for high-performance networking.

**Add Helm repo:**
```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
```

**Create values file** `../k8s/bootstrap/cilium/values.yaml`:
```yaml
# Cilium configuration for Talos + Beelink cluster
ipam:
  mode: kubernetes

kubeProxyReplacement: strict
k8sServiceHost: 192.168.1.20  # VIP for K8s API
k8sServicePort: 6443

securityContext:
  capabilities:
    ciliumAgent:
      - CHOWN
      - KILL
      - NET_ADMIN
      - NET_RAW
      - IPC_LOCK
      - SYS_ADMIN
      - SYS_RESOURCE
      - DAC_OVERRIDE
      - FOWNER
      - SETGID
      - SETUID
    cleanCiliumState:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_RESOURCE

cgroup:
  autoMount:
    enabled: false
  hostRoot: /sys/fs/cgroup

# Enable Hubble for observability
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true

# Enable Ingress Controller
ingressController:
  enabled: true
  loadbalancerMode: shared
  default: true

# Enable Gateway API
gatewayAPI:
  enabled: false  # Enable if you want Gateway API instead of Ingress
```

**Install Cilium:**
```bash
helm install cilium cilium/cilium \
  --version 1.16.5 \
  --namespace kube-system \
  --values ../k8s/bootstrap/cilium/values.yaml
```

**Wait for Cilium to be ready:**
```bash
kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=300s
```

**Verify nodes are now Ready:**
```bash
kubectl get nodes
# Both nodes should show "Ready"
```

**Install Cilium CLI (optional but recommended):**
```bash
# macOS
brew install cilium-cli

# Linux
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
```

**Run connectivity test:**
```bash
cilium connectivity test
```

### 4.2 Install MetalLB (Load Balancer)

MetalLB provides LoadBalancer services in bare-metal environments.

**Install MetalLB:**
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
```

**Wait for MetalLB to be ready:**
```bash
kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=300s
```

**Create IP Address Pool** `../k8s/bootstrap/metallb/ippool.yaml`:
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.1.210-192.168.1.220  # Pool of 11 IPs for LoadBalancers
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
```

**Apply:**
```bash
kubectl apply -f ../k8s/bootstrap/metallb/ippool.yaml
```

### 4.3 Install cert-manager (Certificate Management)

**Add Helm repo:**
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

**Install cert-manager:**
```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.3 \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager
```

**Wait for cert-manager:**
```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
```

**Create ClusterIssuer** `../k8s/bootstrap/cert-manager/clusterissuer.yaml`:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # CHANGE THIS
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - dns01:
          cloudflare:
            email: your-cloudflare-email@example.com  # CHANGE THIS
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
---
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
type: Opaque
stringData:
  api-token: your-cloudflare-api-token  # CHANGE THIS
```

**Apply:**
```bash
kubectl apply -f ../k8s/bootstrap/cert-manager/clusterissuer.yaml
```

---

## Phase 5: Storage Integration

### 5.1 Install NFS CSI Driver

**Add Helm repo:**
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update
```

**Create values file** `../k8s/infrastructure/nfs-provisioner/values.yaml`:
```yaml
nfs:
  server: 192.168.1.5  # Synology NAS IP
  path: /volume1/k8s-pv  # NFS share path

storageClass:
  name: nfs-client
  defaultClass: true
  reclaimPolicy: Retain  # Change to Delete if you want auto-cleanup
  archiveOnDelete: true  # Move deleted PVs to archived-<pvc-name>

# Resource limits
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 10m
    memory: 32Mi
```

**Install NFS provisioner:**
```bash
helm install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace kube-system \
  --values ../k8s/infrastructure/nfs-provisioner/values.yaml
```

**Verify StorageClass:**
```bash
kubectl get storageclass
# Should show nfs-client as (default)
```

**Test PVC** `test-pvc.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: nfs-client
```

```bash
kubectl apply -f test-pvc.yaml
kubectl get pvc test-pvc
# Should show Bound status

# Cleanup
kubectl delete pvc test-pvc
```

---

## Phase 6: Observability Stack

### 6.1 Install kube-prometheus-stack

**Add Helm repo:**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

**Create values file** `../k8s/infrastructure/monitoring/values.yaml`:
```yaml
# Prometheus configuration
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: nfs-client
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi

# Grafana configuration
grafana:
  enabled: true
  adminPassword: changeme-strong-password  # CHANGE THIS
  persistence:
    enabled: true
    storageClassName: nfs-client
    size: 10Gi
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  # Enable ingress
  ingress:
    enabled: true
    ingressClassName: cilium
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - grafana-k8s.yourdomain.com  # CHANGE THIS
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana-k8s.yourdomain.com

# AlertManager
alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: nfs-client
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

# Enable additional exporters
kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

# Talos-specific metrics
kubelet:
  enabled: true
  namespace: kube-system
```

**Install:**
```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values ../k8s/infrastructure/monitoring/values.yaml
```

**Wait for deployment:**
```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
```

**Access Grafana:**
```bash
# Port-forward (temporary access)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open browser to http://localhost:3000
# Username: admin
# Password: (from values.yaml)
```

### 6.2 Install Loki Stack (Logging)

**Add Helm repo:**
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

**Create values file** `../k8s/infrastructure/logging/values.yaml`:
```yaml
loki:
  auth_enabled: false
  storage:
    type: filesystem
  persistence:
    enabled: true
    storageClassName: nfs-client
    size: 100Gi

promtail:
  enabled: true
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

grafana:
  enabled: false  # Already installed in monitoring namespace
  sidecar:
    datasources:
      enabled: true
```

**Install:**
```bash
helm install loki grafana/loki-stack \
  --namespace logging \
  --create-namespace \
  --values ../k8s/infrastructure/logging/values.yaml
```

**Add Loki datasource to Grafana:**

Create `../k8s/infrastructure/logging/grafana-datasource.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-datasource
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |-
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://loki.logging.svc.cluster.local:3100
        jsonData:
          maxLines: 1000
```

```bash
kubectl apply -f ../k8s/infrastructure/logging/grafana-datasource.yaml
```

---

## Phase 7: GitOps Setup

### 7.1 Install ArgoCD

**Install ArgoCD:**
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Wait for ArgoCD:**
```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

**Get initial admin password:**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# Copy this password
```

**Access ArgoCD UI:**
```bash
# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser to https://localhost:8080
# Username: admin
# Password: (from above command)
```

**Change admin password:**
```bash
# Install argocd CLI
brew install argocd  # macOS
# or download from https://github.com/argoproj/argo-cd/releases

# Login
argocd login localhost:8080

# Change password
argocd account update-password
```

### 7.2 Create ArgoCD Ingress

Create `../k8s/bootstrap/argocd/ingress.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  ingressClassName: cilium
  rules:
    - host: argocd-k8s.yourdomain.com  # CHANGE THIS
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
  tls:
    - hosts:
        - argocd-k8s.yourdomain.com
      secretName: argocd-server-tls
```

```bash
kubectl apply -f ../k8s/bootstrap/argocd/ingress.yaml
```

---

## Phase 8: Security Hardening

### 8.1 Install Conjur for Secrets Management

Conjur provides enterprise-grade secrets management with detailed audit logs and policy-based access control.

#### Option A: CyberArk Conjur OSS (Recommended for Home Lab)

**Deploy Conjur OSS:**

Create `../k8s/infrastructure/external-secrets/conjur-deploy.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: conjur
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: conjur-oss
  namespace: conjur
spec:
  replicas: 1
  selector:
    matchLabels:
      app: conjur-oss
  template:
    metadata:
      labels:
        app: conjur-oss
    spec:
      containers:
        - name: conjur
          image: cyberark/conjur:latest
          ports:
            - containerPort: 80
          env:
            - name: DATABASE_URL
              value: "postgres://postgres@conjur-postgres/postgres"
            - name: CONJUR_DATA_KEY
              valueFrom:
                secretKeyRef:
                  name: conjur-data-key
                  key: key
          volumeMounts:
            - name: conjur-data
              mountPath: /var/lib/conjur
      volumes:
        - name: conjur-data
          persistentVolumeClaim:
            claimName: conjur-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: conjur-data
  namespace: conjur
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: conjur-oss
  namespace: conjur
spec:
  selector:
    app: conjur-oss
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

**Deploy PostgreSQL for Conjur:**

Create `../k8s/infrastructure/external-secrets/conjur-postgres.yaml`:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: conjur-postgres
  namespace: conjur
spec:
  serviceName: conjur-postgres
  replicas: 1
  selector:
    matchLabels:
      app: conjur-postgres
  template:
    metadata:
      labels:
        app: conjur-postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15-alpine
          env:
            - name: POSTGRES_HOST_AUTH_METHOD
              value: trust
            - name: POSTGRES_DB
              value: postgres
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: postgres-data
          persistentVolumeClaim:
            claimName: conjur-postgres-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: conjur-postgres-data
  namespace: conjur
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: conjur-postgres
  namespace: conjur
spec:
  selector:
    app: conjur-postgres
  ports:
    - port: 5432
      targetPort: 5432
  clusterIP: None
```

**Generate Conjur data key:**
```bash
# Generate secure data key
CONJUR_DATA_KEY=$(openssl rand -base64 32)

# Create secret
kubectl create secret generic conjur-data-key \
  --from-literal=key=$CONJUR_DATA_KEY \
  --namespace conjur
```

**Deploy Conjur:**
```bash
kubectl apply -f ../k8s/infrastructure/external-secrets/conjur-postgres.yaml
kubectl apply -f ../k8s/infrastructure/external-secrets/conjur-deploy.yaml
```

**Initialize Conjur:**
```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=conjur-oss -n conjur --timeout=300s

# Get Conjur pod name
CONJUR_POD=$(kubectl get pod -n conjur -l app=conjur-oss -o jsonpath='{.items[0].metadata.name}')

# Initialize Conjur account
kubectl exec -n conjur $CONJUR_POD -- conjurctl account create default

# Save the API key displayed - you'll need this!
```

#### Option B: External Secrets Operator with Conjur Backend

**Install External Secrets Operator:**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace
```

**Create Conjur SecretStore:**

Create `../k8s/infrastructure/external-secrets/conjur-secretstore.yaml`:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: conjur
  namespace: default
spec:
  provider:
    conjur:
      url: http://conjur-oss.conjur.svc.cluster.local
      auth:
        apikey:
          account: default
          userRef:
            key: username
          apiKeyRef:
            key: apikey
---
apiVersion: v1
kind: Secret
metadata:
  name: conjur-creds
  namespace: default
type: Opaque
stringData:
  username: admin
  apikey: <api-key-from-initialization>  # CHANGE THIS
```

**Example: Create External Secret:**

Create `../k8s/infrastructure/external-secrets/example-external-secret.yaml`:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: conjur
    kind: SecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: database/username
    - secretKey: password
      remoteRef:
        key: database/password
```

**Conjur CLI Setup (for managing secrets):**

Install Conjur CLI:
```bash
# macOS
brew tap cyberark/tools
brew install cyberark/tools/conjur-cli

# Linux
docker pull cyberark/conjur-cli:latest
alias conjur='docker run --rm -it --network host cyberark/conjur-cli:latest'
```

**Initialize Conjur CLI:**
```bash
# Port-forward Conjur service
kubectl port-forward -n conjur svc/conjur-oss 8080:80

# Initialize
conjur init -u http://localhost:8080 -a default

# Login
conjur login -i admin
# Enter API key when prompted
```

**Load secrets into Conjur:**

Create policy file `k8s-secrets-policy.yml`:
```yaml
- !policy
  id: k8s-secrets
  body:
    - !variable database/username
    - !variable database/password
    - !variable api/token
    - !variable tls/cert
    - !variable tls/key
```

```bash
# Load policy
conjur policy load root k8s-secrets-policy.yml

# Set secret values
conjur variable set -i k8s-secrets/database/username -v "dbuser"
conjur variable set -i k8s-secrets/database/password -v "super-secret-password"
conjur variable set -i k8s-secrets/api/token -v "api-token-value"
```

### 8.2 Enable Pod Security Standards

**Create namespace with restricted policy** `restricted-namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 8.3 Install Trivy Operator (Vulnerability Scanning)

**Add Helm repo:**
```bash
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update
```

**Install:**
```bash
helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --create-namespace
```

---

## Phase 9: Backup & DR

### 9.1 Install Velero

**Install Velero CLI:**
```bash
# macOS
brew install velero

# Linux
wget https://github.com/vmware-tanzu/velero/releases/download/v1.15.0/velero-v1.15.0-linux-amd64.tar.gz
tar -xvf velero-v1.15.0-linux-amd64.tar.gz
sudo mv velero-v1.15.0-linux-amd64/velero /usr/local/bin/
```

**Create Velero values** `../k8s/infrastructure/velero/values.yaml`:
```yaml
configuration:
  backupStorageLocation:
    - name: default
      provider: aws
      bucket: k8s-backups
      config:
        region: minio
        s3ForcePathStyle: "true"
        s3Url: http://192.168.1.5:9000  # MinIO on Synology

  volumeSnapshotLocation:
    - name: default
      provider: aws
      config:
        region: minio

credentials:
  useSecret: true
  secretContents:
    cloud: |
      [default]
      aws_access_key_id=minioadmin
      aws_secret_access_key=minioadmin

# Or use NFS directly
# initContainers:
#   - name: velero-plugin-for-nfs
#     image: velero/velero-plugin-for-nfs:latest
```

**Note**: You'll need to set up MinIO on Synology or use NFS plugin for backups.

---

## Verification & Testing

### Cluster Health Checks

```bash
# Check all nodes
kubectl get nodes -o wide

# Check all pods
kubectl get pods -A

# Check Talos health
talosctl health

# Check Cilium connectivity
cilium connectivity test

# Check MetalLB
kubectl get ipaddresspool -n metallb-system

# Check storage
kubectl get sc
kubectl get pv
kubectl get pvc -A

# Check monitoring
kubectl get pods -n monitoring
kubectl get pods -n logging
```

### Deploy Test Application

Create `test-app.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test
  namespace: default
spec:
  type: LoadBalancer
  selector:
    app: nginx-test
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f test-app.yaml
kubectl get svc nginx-test
# Note the EXTERNAL-IP (should be from MetalLB pool)

# Test access
curl http://<external-ip>

# Cleanup
kubectl delete -f test-app.yaml
```

---

## Troubleshooting

### Nodes Not Ready

```bash
# Check Cilium status
kubectl get pods -n kube-system -l k8s-app=cilium

# Check Cilium logs
kubectl logs -n kube-system -l k8s-app=cilium

# Restart Cilium
kubectl rollout restart ds/cilium -n kube-system
```

### Storage Issues

```bash
# Check NFS provisioner
kubectl get pods -n kube-system -l app=nfs-subdir-external-provisioner

# Check NFS mount from Talos VM
talosctl -n 192.168.1.21 dmesg | grep -i nfs

# Test NFS connectivity
showmount -e 192.168.1.5
```

### Certificate Issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate status
kubectl get certificate -A
kubectl describe certificate <cert-name> -n <namespace>
```

---

## Next Steps

1. **Set up GitOps repository** - Create Git repo for all manifests
2. **Configure ArgoCD Applications** - Auto-deploy from Git
3. **Migrate services** - See [K8S_MIGRATION.md](K8S_MIGRATION.md)
4. **Set up monitoring alerts** - Configure AlertManager rules
5. **Test disaster recovery** - Practice cluster restoration
6. **Document runbooks** - Create operational procedures

---

## Additional Resources

- **Proxmox Documentation**: https://pve.proxmox.com/pve-docs/
- **Talos Documentation**: https://www.talos.dev/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Cilium Documentation**: https://docs.cilium.io/
- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **Prometheus Operator**: https://prometheus-operator.dev/

---

**Last Updated**: 2025-12-09

[Back to Main README](../README.md) | [Proxmox Setup](PROXMOX_SETUP.md) | [K8s Manifests](../k8s/README.md) | [Secrets Management](SECRETS_MANAGEMENT.md)
