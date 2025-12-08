# Kubernetes Home Stack

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Talos-326CE5?logo=kubernetes)](https://www.talos.dev/)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE%209.x-E57000?logo=proxmox)](https://www.proxmox.com/)

Production-ready Kubernetes configurations for home lab deployment on Talos Linux.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Service Catalog](#service-catalog)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This repository provides:

1. **Kubernetes Manifests**: Production-grade Kustomize configurations for Talos Linux cluster
2. **Infrastructure as Code**: Terraform and Ansible for Proxmox VM provisioning
3. **Comprehensive Documentation**: Setup guides, operations manuals, and troubleshooting

### Use Cases

- Home server with centralized storage, password management, and secure access
- Small office with document sharing and monitoring
- Learning platform for Kubernetes and cloud-native technologies

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Home Network (192.168.1.0/24)                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                  PROXMOX VE 9.x HA CLUSTER                       │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │    │
│  │  │ pve1 (.11)  │  │ pve2 (.12)  │  │ pve3 (.13)  │              │    │
│  │  │ Beelink #1  │  │ Beelink #2  │  │ Beelink #3  │              │    │
│  │  │ ─────────── │  │ ─────────── │  │ ─────────── │              │    │
│  │  │ │ VM 100  │ │  │ │ VM 101  │ │  │ │ VM 102  │ │              │    │
│  │  │ │talos-cp │ │  │ │ worker-2│ │  │ │ worker-3│ │              │    │
│  │  │ │  (.21)  │ │  │ │  (.22)  │ │  │ │  (.23)  │ │              │    │
│  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │              │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                   ┌──────────▼──────────┐                               │
│                   │  Kubernetes Cluster │  K8s API VIP: .20             │
│                   │  ─────────────────  │                               │
│                   │  Traefik, Authelia  │                               │
│                   │  Vaultwarden        │                               │
│                   │  Nextcloud, Homepage│                               │
│                   │  ArgoCD, Prometheus │                               │
│                   │  Grafana, Loki      │                               │
│                   │  Jaeger, Conjur     │                               │
│                   └──────────┬──────────┘                               │
│                              │ NFS Storage                               │
│                   ┌──────────▼──────────┐                               │
│                   │  Synology DS 224+   │                               │
│                   │  192.168.1.5        │                               │
│                   │  ────────────────── │                               │
│                   │  NFS: K8s PVs       │                               │
│                   │  Backups: Velero    │                               │
│                   └─────────────────────┘                               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### IP Address Reference

| Resource | IP Address | Purpose |
|----------|------------|---------|
| Proxmox Host 1 | 192.168.1.11 | pve1 - Hypervisor |
| Proxmox Host 2 | 192.168.1.12 | pve2 - Hypervisor |
| Proxmox Host 3 | 192.168.1.13 | pve3 - Hypervisor |
| Talos VM 1 | 192.168.1.21 | Control plane + worker |
| Talos VM 2 | 192.168.1.22 | Worker |
| Talos VM 3 | 192.168.1.23 | Worker |
| K8s API VIP | 192.168.1.20 | Kubernetes API endpoint |
| MetalLB Pool | 192.168.1.210-220 | Service LoadBalancers |
| Synology NAS | 192.168.1.5 | NFS storage for PVs |

---

## Hardware

- **3x Beelink Mini S13** (Intel N150, 4 cores each)
- **Proxmox VE 9.x** on each node (HA cluster)
- **3x Talos VMs** (12GB RAM, 3 vCPU, 100GB disk each)
- **Synology DS 224+** (NFS storage, backups)

## Software Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| OS | Talos Linux | Immutable, API-managed |
| CNI | Cilium | eBPF networking |
| Storage | NFS CSI | Synology integration |
| Load Balancer | MetalLB | Bare-metal LB |
| Ingress | Traefik | Reverse proxy, HTTPS |
| Certificates | cert-manager | Let's Encrypt |
| Secrets | Conjur OSS | Enterprise secrets |
| GitOps | ArgoCD | Declarative deployments |
| Metrics | Prometheus | Monitoring |
| Visualization | Grafana | Dashboards |
| Logging | Loki | Log aggregation |
| Tracing | Jaeger | Distributed tracing |
| Backups | Velero | Cluster backups |

### Component Versions

| Component | Version |
|-----------|---------|
| Talos Linux | v1.9.x |
| Kubernetes | 1.29.x |
| Proxmox VE | 9.x |
| Cilium | 1.15.x |
| Traefik | 3.x |

---

## Quick Start

```bash
# 1. Review setup guides
cat docs/PROXMOX_SETUP.md
cat docs/TALOS_KUBERNETES_SETUP.md

# 2. Install Proxmox VE on Beelinks (.11, .12, .13)
# 3. Create Proxmox cluster and configure HA
# 4. Create Talos VMs (100, 101, 102)

# 5. Apply Talos configurations
cd talos
talosctl gen config my-cluster https://192.168.1.20:6443
talosctl apply-config --insecure --nodes <dhcp-ip> --file controlplane.yaml
talosctl apply-config --insecure --nodes <dhcp-ip> --file worker-2.yaml
talosctl apply-config --insecure --nodes <dhcp-ip> --file worker-3.yaml

# 6. Bootstrap cluster
talosctl bootstrap --nodes 192.168.1.21

# 7. Get kubeconfig
talosctl kubeconfig .
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes

# 8. Deploy infrastructure
kubectl apply -k k8s/bootstrap/cilium/
kubectl apply -k k8s/bootstrap/metallb/
kubectl apply -k k8s/bootstrap/cert-manager/
kubectl apply -k k8s/infrastructure/nfs-provisioner/

# 9. Deploy applications
kubectl apply -k k8s/overlays/production/
```

See [TALOS_KUBERNETES_SETUP.md](docs/TALOS_KUBERNETES_SETUP.md) for detailed instructions.

---

## Documentation

### Core Guides

| Document | Description |
|----------|-------------|
| [Talos Setup](docs/TALOS_KUBERNETES_SETUP.md) | Kubernetes cluster installation |
| [Proxmox Setup](docs/PROXMOX_SETUP.md) | Hypervisor configuration |
| [Architecture](docs/K8S_ARCHITECTURE.md) | Design decisions |
| [Operations](docs/K8S_OPERATIONS.md) | Day-2 operations |
| [Quick Reference](docs/K8S_QUICK_REFERENCE.md) | Common commands |

### Configuration Guides

| Document | Description |
|----------|-------------|
| [Secrets Management](docs/SECRETS_MANAGEMENT.md) | Kustomize, Conjur, ESO |
| [Validation Checklist](docs/VALIDATION_CHECKLIST.md) | Production readiness |
| [Pre-Deployment](docs/PRE_DEPLOYMENT_CHECKLIST.md) | Deployment checklist |
| [Security](docs/SECURITY.md) | Security hardening |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues |

### Infrastructure

| Document | Description |
|----------|-------------|
| [Infrastructure as Code](infrastructure/README.md) | Terraform and Ansible |
| [K8s Manifests](k8s/README.md) | Kustomize structure |
| [Optional Enhancements](k8s/optional/README.md) | Additional tools |

---

## Service Catalog

### Core Services

| Service | Purpose | Namespace |
|---------|---------|-----------|
| Traefik | Ingress controller | traefik |
| Authelia | SSO with 2FA | authelia |
| Vaultwarden | Password manager | vaultwarden |
| Nextcloud | File sync | nextcloud |
| Homepage | Dashboard | homepage |
| IT-Tools | Utilities | it-tools |

### Infrastructure Services

| Service | Purpose | Namespace |
|---------|---------|-----------|
| ArgoCD | GitOps | argocd |
| Prometheus | Metrics | monitoring |
| Grafana | Dashboards | monitoring |
| Loki | Logging | logging |
| Jaeger | Tracing | tracing |
| Conjur | Secrets | conjur |
| Velero | Backups | velero |

---

## Directory Structure

```
synology_containers/
├── docs/                    # Documentation
├── infrastructure/          # Terraform and Ansible
│   ├── terraform/           # VM provisioning
│   └── ansible/             # Node configuration
├── k8s/                     # Kubernetes manifests
│   ├── base/                # Base configurations
│   ├── overlays/            # Environment overlays
│   ├── infrastructure/      # Infrastructure components
│   └── optional/            # Optional enhancements
├── talos/                   # Talos configurations
├── scripts/                 # Helper scripts
└── README.md                # This file
```

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

---

[Documentation](docs/) | [K8s Manifests](k8s/) | [Infrastructure](infrastructure/)
