# Infrastructure as Code (IaC)

This directory contains Infrastructure as Code configurations for the homelab environment using **Terraform** and **Ansible**.

## Overview

```
infrastructure/
├── terraform/
│   ├── proxmox/          # Proxmox VM provisioning
│   │   ├── main.tf       # VM resources
│   │   ├── variables.tf  # Configuration variables
│   │   ├── outputs.tf    # Output values
│   │   └── terraform.tfvars.example
│   └── talos/            # Talos cluster configuration
│       ├── main.tf       # Cluster bootstrap
│       ├── variables.tf  # Cluster settings
│       ├── outputs.tf    # Kubeconfig, endpoints
│       └── terraform.tfvars.example
├── ansible/
│   ├── inventory/        # Host definitions
│   │   └── hosts.yml
│   ├── playbooks/        # Automation playbooks
│   │   ├── proxmox-setup.yml    # Initial node config
│   │   ├── proxmox-cluster.yml  # Cluster formation
│   │   └── proxmox-vms.yml      # VM creation
│   ├── roles/            # Reusable roles
│   └── ansible.cfg       # Ansible configuration
└── README.md             # This file
```

## Quick Start

### Prerequisites

```bash
# Install Terraform
brew install terraform   # macOS
# or: https://developer.hashicorp.com/terraform/downloads

# Install Ansible
brew install ansible     # macOS
pip install ansible      # Linux

# Install required Ansible collections
ansible-galaxy collection install community.general
```

### 1. Configure Proxmox Nodes (Ansible)

```bash
cd infrastructure/ansible

# Edit inventory with your IPs
vim inventory/hosts.yml

# Run initial setup on all Proxmox nodes
ansible-playbook playbooks/proxmox-setup.yml

# Form the cluster
ansible-playbook playbooks/proxmox-cluster.yml
```

### 2. Create Talos VMs (Terraform)

```bash
cd infrastructure/terraform/proxmox

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars   # Set your Proxmox password

# Initialize and apply
terraform init
terraform plan
terraform apply
```

### 3. Bootstrap Talos Cluster (Terraform)

```bash
cd infrastructure/terraform/talos

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars

# Initialize and apply
terraform init
terraform plan
terraform apply

# Export kubeconfig
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
kubectl get nodes
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GitOps Pipeline                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐  │
│  │   Git Repo   │───▶│   GitHub     │───▶│  Terraform Apply     │  │
│  │   (IaC)      │    │   Actions    │    │  (Infrastructure)    │  │
│  └──────────────┘    └──────────────┘    └──────────┬───────────┘  │
│                                                      │              │
│                                                      ▼              │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Proxmox VE Cluster                         │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐              │  │
│  │  │   pve1     │  │   pve2     │  │   pve3     │              │  │
│  │  │  VM 100    │  │  VM 101    │  │  VM 102    │              │  │
│  │  │  Talos CP  │  │  Talos W2  │  │  Talos W3  │              │  │
│  │  └────────────┘  └────────────┘  └────────────┘              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                │                                    │
│                                ▼                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                 Kubernetes Cluster                            │  │
│  │                                                               │  │
│  │  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │  │
│  │  │ ArgoCD  │─▶│ Kustomize│─▶│ Services │  │  Monitoring  │  │  │
│  │  │ (GitOps)│  │ Overlays │  │  Stack   │  │    Stack     │  │  │
│  │  └─────────┘  └──────────┘  └──────────┘  └──────────────┘  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Terraform Modules

### Proxmox Module (`terraform/proxmox/`)

Creates virtual machines on Proxmox VE for running Talos Linux.

**Resources Created:**
- 3x VMs (100, 101, 102) with:
  - 12GB RAM (no ballooning)
  - 3 vCPU cores (host type)
  - 100GB virtio-scsi disk
  - virtio network adapter

**Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `proxmox_api_url` | `https://192.168.1.11:8006/api2/json` | Proxmox API endpoint |
| `vm_cpu_cores` | `3` | CPU cores per VM |
| `vm_memory_mb` | `12288` | Memory in MB |
| `vm_disk_size_gb` | `100` | Disk size in GB |
| `talos_iso_file` | `local:iso/talos-amd64.iso` | Talos ISO path |

### Talos Module (`terraform/talos/`)

Configures and bootstraps the Talos Kubernetes cluster.

**Resources Created:**
- Machine secrets
- Control plane configuration
- Worker configurations
- Cluster bootstrap
- Kubeconfig file

**Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_name` | `talos-cluster` | Kubernetes cluster name |
| `talos_version` | `v1.9.x` | Talos Linux version (check [releases](https://github.com/siderolabs/talos/releases)) |
| `kubernetes_version` | `1.29.x` | Kubernetes version (current production) |
| `kubernetes_api_vip` | `192.168.1.20` | API server VIP |

> **Version Note**: Update `talos_version` and `kubernetes_version` in `terraform.tfvars` to match your target deployment. Always test upgrades in staging first.

## Ansible Playbooks

### `proxmox-setup.yml`
Initial configuration of Proxmox nodes:
- Repository configuration (enterprise/no-subscription)
- Package updates and tools installation
- NTP configuration
- Security hardening

### `proxmox-cluster.yml`
Cluster formation:
- Create cluster on master node
- Join worker nodes
- Configure shared NFS storage
- Set up HA groups

### `proxmox-vms.yml`
VM creation (alternative to Terraform):
- Create VMs with specified resources
- Attach Talos ISO
- Add to HA group

## CI/CD Integration

The `.github/workflows/terraform.yml` workflow:

1. **On Pull Request:**
   - Validates Terraform syntax
   - Runs security scan (tfsec)
   - Generates plan and comments on PR

2. **On Push to Main:**
   - Applies Terraform changes
   - Uploads state as artifact

### Required Secrets

Configure these in GitHub repository settings:

| Secret | Description |
|--------|-------------|
| `PROXMOX_API_PASSWORD` | Proxmox root password or API token |

## State Management

### Local State (Development)
```bash
# State stored locally in terraform.tfstate
terraform apply
```

### Remote State (Production)

Uncomment the backend configuration in `main.tf`:

```hcl
backend "s3" {
  bucket   = "terraform-state"
  key      = "proxmox/terraform.tfstate"
  endpoint = "http://192.168.1.5:9000"  # MinIO
  # ...
}
```

Then initialize:
```bash
terraform init -migrate-state
```

## Troubleshooting

### Terraform Can't Connect to Proxmox

```bash
# Test API connectivity
curl -k https://192.168.1.11:8006/api2/json/version

# Verify credentials
curl -k -d "username=root@pam&password=YOUR_PASSWORD" \
  https://192.168.1.11:8006/api2/json/access/ticket
```

### Ansible SSH Issues

```bash
# Test connectivity
ansible proxmox -m ping

# Debug SSH
ansible proxmox -m ping -vvv

# Check SSH keys
ssh-copy-id root@192.168.1.11
```

### Talos Bootstrap Fails

```bash
# Check Talos node status
talosctl -n 192.168.1.21 dmesg

# View machine config
talosctl -n 192.168.1.21 get machineconfig

# Reset and retry
talosctl -n 192.168.1.21 reset --graceful=false
```

## Best Practices

1. **Never commit secrets** - Use `.gitignore` for `*.tfvars`
2. **Use remote state** - Enable S3 backend for team collaboration
3. **Version pin providers** - Avoid unexpected changes
4. **Review plans** - Always review `terraform plan` before apply
5. **Use workspaces** - Separate dev/staging/production
6. **Document changes** - Update this README when modifying IaC

## Related Documentation

- [Proxmox Setup Guide](../docs/PROXMOX_SETUP.md)
- [Talos Kubernetes Setup](../docs/TALOS_KUBERNETES_SETUP.md)
- [K8s Architecture](../docs/K8S_ARCHITECTURE.md)
- [Infrastructure as Code Guide](../docs/INFRASTRUCTURE_AS_CODE.md)
- [Secrets Management Guide](../docs/SECRETS_MANAGEMENT.md)

---

[Back to Main README](../README.md) | [K8s Manifests](../k8s/README.md) | [Talos Config](../talos/README.md)
