# Infrastructure as Code Guide

This guide covers the Infrastructure as Code (IaC) approach for managing the homelab infrastructure using Terraform and Ansible.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Infrastructure as Code Stack                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Layer 4: Applications (Kubernetes)                                      ││
│  │  ─────────────────────────────────                                       ││
│  │  • ArgoCD (GitOps)                                                       ││
│  │  • Kustomize overlays                                                    ││
│  │  • Helm charts                                                           ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                    ▲                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Layer 3: Kubernetes Cluster (Terraform - Talos Provider)                ││
│  │  ────────────────────────────────────────────────────                    ││
│  │  • Machine secrets generation                                            ││
│  │  • Control plane configuration                                           ││
│  │  • Worker configuration                                                  ││
│  │  • Cluster bootstrap                                                     ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                    ▲                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Layer 2: Virtual Machines (Terraform - Proxmox Provider)                ││
│  │  ────────────────────────────────────────────────────                    ││
│  │  • VM creation (100, 101, 102)                                           ││
│  │  • Resource allocation (CPU, RAM, disk)                                  ││
│  │  • Network configuration                                                 ││
│  │  • ISO attachment                                                        ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                    ▲                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Layer 1: Hypervisor (Ansible)                                           ││
│  │  ─────────────────────────────                                           ││
│  │  • Proxmox initial setup                                                 ││
│  │  • Cluster formation                                                     ││
│  │  • NFS storage configuration                                             ││
│  │  • HA groups                                                             ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
infrastructure/
├── terraform/
│   ├── proxmox/                    # Proxmox VM provisioning
│   │   ├── main.tf                 # VM resources
│   │   ├── variables.tf            # Input variables
│   │   ├── outputs.tf              # Output values
│   │   └── terraform.tfvars.example
│   └── talos/                      # Talos cluster configuration
│       ├── main.tf                 # Cluster resources
│       ├── variables.tf            # Cluster variables
│       ├── outputs.tf              # Kubeconfig, endpoints
│       └── terraform.tfvars.example
├── ansible/
│   ├── inventory/
│   │   └── hosts.yml               # Host definitions
│   ├── playbooks/
│   │   ├── proxmox-setup.yml       # Initial node config
│   │   ├── proxmox-cluster.yml     # Cluster formation
│   │   └── proxmox-vms.yml         # VM creation (alt to Terraform)
│   ├── roles/                      # Reusable roles
│   └── ansible.cfg                 # Configuration
└── README.md
```

---

## Getting Started

### Prerequisites

```bash
# Install Terraform (>= 1.5.0)
brew install terraform                    # macOS
# Or download from https://terraform.io

# Install Ansible (>= 2.15)
brew install ansible                      # macOS
pip install ansible                       # Linux

# Verify installations
terraform version
ansible --version
```

### Initial Setup

**1. Clone Repository:**
```bash
git clone https://github.com/your-repo/synology_containers.git
cd synology_containers/infrastructure
```

**2. Configure Ansible Inventory:**
```bash
cd ansible
cp inventory/hosts.yml.example inventory/hosts.yml
vim inventory/hosts.yml  # Edit with your IPs
```

**3. Configure Terraform Variables:**
```bash
cd ../terraform/proxmox
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Set Proxmox credentials
```

---

## Terraform Usage

### Proxmox VM Provisioning

**Initialize:**
```bash
cd infrastructure/terraform/proxmox
terraform init
```

**Plan:**
```bash
terraform plan -out=tfplan
```

**Apply:**
```bash
terraform apply tfplan
```

**Outputs:**
```bash
terraform output talos_vms
terraform output kubernetes_api_vip
```

### Talos Cluster Configuration

**Initialize:**
```bash
cd infrastructure/terraform/talos
terraform init
```

**Apply:**
```bash
terraform apply

# This will:
# 1. Generate machine secrets
# 2. Create control plane config
# 3. Create worker configs
# 4. Apply configs to VMs
# 5. Bootstrap the cluster
# 6. Generate kubeconfig
```

**Export Credentials:**
```bash
export TALOSCONFIG=$(terraform output -raw talosconfig_path)
export KUBECONFIG=$(terraform output -raw kubeconfig_path)

# Verify
talosctl health
kubectl get nodes
```

---

## Ansible Usage

### Proxmox Initial Setup

**Run Setup Playbook:**
```bash
cd infrastructure/ansible
ansible-playbook playbooks/proxmox-setup.yml
```

This playbook:
- Configures no-subscription repository
- Updates packages
- Removes subscription nag
- Configures NTP
- Hardens SSH

### Proxmox Cluster Formation

**Form Cluster:**
```bash
ansible-playbook playbooks/proxmox-cluster.yml
```

This playbook:
- Creates cluster on master node
- Joins other nodes
- Configures NFS storage
- Sets up HA groups

### Verify Cluster

```bash
# Check cluster status
ansible proxmox -m shell -a "pvecm status"

# Check nodes
ansible proxmox -m shell -a "pvecm nodes"
```

---

## GitOps Workflow

### Complete Infrastructure Deployment

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         GitOps Deployment Flow                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐   │
│  │    Git      │───▶│   GitHub    │───▶│  Terraform  │───▶│  Proxmox    │   │
│  │   Push      │    │   Actions   │    │   Apply     │    │    VMs      │   │
│  └─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘   │
│                                                                   │          │
│                                                                   ▼          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐   │
│  │ Kubernetes  │◀───│   ArgoCD    │◀───│   Talos     │◀───│   Talos     │   │
│  │   Workloads │    │   Sync      │    │  Bootstrap  │    │   Config    │   │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘   │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Step-by-Step Deployment

**Step 1: Proxmox Setup (Ansible)**
```bash
cd infrastructure/ansible
ansible-playbook playbooks/proxmox-setup.yml
ansible-playbook playbooks/proxmox-cluster.yml
```

**Step 2: Create VMs (Terraform)**
```bash
cd infrastructure/terraform/proxmox
terraform init && terraform apply
```

**Step 3: Bootstrap Talos (Terraform)**
```bash
cd infrastructure/terraform/talos
terraform init && terraform apply
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
```

**Step 4: Install Core Components**
```bash
# Cilium CNI
kubectl apply -k k8s/bootstrap/cilium/

# MetalLB
kubectl apply -k k8s/bootstrap/metallb/

# cert-manager
kubectl apply -k k8s/bootstrap/cert-manager/

# ArgoCD
kubectl apply -k k8s/bootstrap/argocd/
```

**Step 5: Deploy Applications via ArgoCD**
```bash
# Configure ArgoCD to watch Git repo
kubectl apply -f k8s/argocd-app.yaml

# ArgoCD will automatically deploy:
# - Monitoring (Prometheus, Grafana, Loki)
# - Security (Conjur, NetworkPolicies)
# - Applications (Homepage, Vaultwarden, etc.)
```

---

## State Management

### Local State (Development)

```bash
# State stored in terraform.tfstate locally
terraform apply
```

### Remote State (Production)

**Option 1: MinIO on Synology**

```hcl
# In main.tf
terraform {
  backend "s3" {
    bucket                      = "terraform-state"
    key                         = "proxmox/terraform.tfstate"
    region                      = "us-east-1"
    endpoint                    = "http://192.168.1.5:9000"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

**Setup MinIO:**
```bash
# On Synology (Docker)
docker run -d \
  --name minio \
  -p 9000:9000 \
  -p 9001:9001 \
  -v /volume1/minio:/data \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=minioadmin \
  minio/minio server /data --console-address ":9001"

# Create bucket
mc alias set local http://192.168.1.5:9000 minioadmin minioadmin
mc mb local/terraform-state
```

**Option 2: Git-Encrypted State**

```bash
# Use git-crypt for encrypted state in repo
git-crypt init
echo "*.tfstate filter=git-crypt diff=git-crypt" >> .gitattributes
```

---

## CI/CD Integration

### GitHub Actions Workflow

The `.github/workflows/terraform.yml` workflow provides:

1. **Validation** - Format and syntax checking
2. **Security Scan** - tfsec analysis
3. **Plan** - Preview changes on PRs
4. **Apply** - Auto-deploy on main branch merge

**Required Secrets:**
| Secret | Description |
|--------|-------------|
| `PROXMOX_API_PASSWORD` | Proxmox root password |

**Workflow Triggers:**
- Push to `main` → Auto-apply
- Pull Request → Plan only
- Manual dispatch → Choose action

---

## Best Practices

### 1. Version Pinning

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70"  # Pin to minor version
    }
  }
}
```

### 2. Sensitive Data

```hcl
variable "proxmox_api_password" {
  type      = string
  sensitive = true  # Won't show in logs
}
```

**.gitignore:**
```
*.tfvars
*.tfstate
*.tfstate.backup
.terraform/
```

### 3. Modular Structure

```hcl
# main.tf - Use modules for reusability
module "talos_vm" {
  source = "./modules/proxmox-vm"

  for_each = var.talos_nodes

  name      = each.key
  vmid      = each.value.vmid
  node      = each.value.node
  cpu       = var.vm_cpu_cores
  memory    = var.vm_memory_mb
}
```

### 4. Workspaces

```bash
# Create environment workspaces
terraform workspace new production
terraform workspace new staging
terraform workspace new dev

# Select workspace
terraform workspace select production
terraform apply -var-file=production.tfvars
```

---

## Troubleshooting

### Terraform Issues

**Provider Authentication:**
```bash
# Test Proxmox API
curl -k https://192.168.1.11:8006/api2/json/version

# Test with credentials
curl -k -d "username=root@pam&password=YOURPASS" \
  https://192.168.1.11:8006/api2/json/access/ticket
```

**State Lock:**
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

### Ansible Issues

**SSH Connection:**
```bash
# Test connectivity
ansible proxmox -m ping -vvv

# Copy SSH key
ssh-copy-id root@192.168.1.11
```

**Privilege Escalation:**
```bash
# Run with become
ansible-playbook playbooks/proxmox-setup.yml --become
```

---

## Recovery Procedures

### Recreate Infrastructure

```bash
# Destroy and recreate VMs
cd infrastructure/terraform/proxmox
terraform destroy
terraform apply

# Recreate Talos cluster
cd ../talos
terraform destroy
terraform apply
```

### Import Existing Resources

```bash
# Import existing VM
terraform import proxmox_virtual_environment_vm.talos["talos-cp-1"] pve1/qemu/100
```

---

## Related Documentation

- [Proxmox Setup](PROXMOX_SETUP.md)
- [Talos Kubernetes Setup](TALOS_KUBERNETES_SETUP.md)
- [K8s Architecture](K8S_ARCHITECTURE.md)
- [K8s Operations](K8S_OPERATIONS.md)
- [K8s Migration](K8S_MIGRATION.md)

## External References

- [Terraform Proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest)
- [Terraform Talos Provider](https://registry.terraform.io/providers/siderolabs/talos/latest)
- [Ansible Documentation](https://docs.ansible.com/)
- [Proxmox API](https://pve.proxmox.com/pve-docs/api-viewer/)

---

**Last Updated**: 2025-12-09

[Back to Main README](../README.md) | [Proxmox Setup](PROXMOX_SETUP.md) | [Talos Setup](TALOS_KUBERNETES_SETUP.md) | [Infrastructure Module](../infrastructure/README.md)
