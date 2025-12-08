# Talos Configuration Files

This directory contains Talos Linux configuration files for your Kubernetes cluster running as VMs on Proxmox.

## Security Warning

**NEVER commit the actual configuration files (`controlplane.yaml`, `worker.yaml`, `talosconfig`) to Git!**

These files contain:
- Cluster secrets and tokens
- Certificate private keys
- API credentials

Only the `.example` template files should be in version control.

## Quick Start (Proxmox VMs)

### 1. Prerequisites

Ensure you have completed:
- [Proxmox Setup](../docs/PROXMOX_SETUP.md) - Proxmox installed on all 3 Beelinks
- VMs created (VM IDs: 100, 101, 102)
- Talos ISO uploaded to Proxmox

### 2. Generate Initial Configurations

```bash
cd talos

# Generate base configurations (using K8s API VIP)
talosctl gen config my-cluster https://192.168.1.20:6443 \
  --output-dir .
```

This creates:
- `controlplane.yaml` - Control plane node configuration
- `worker.yaml` - Worker node configuration
- `talosconfig` - Client configuration for talosctl

### 3. Customize Configurations

The generated files need customization. Use the `.example` files as reference:

**For Control Plane (`controlplane.yaml`):**

```bash
# Copy the generated file as backup
cp controlplane.yaml controlplane.yaml.bak

# Edit the configuration
nano controlplane.yaml
```

Key changes for Proxmox VMs:
- Install disk: `/dev/vda` (virtio disk, not `/dev/nvme0n1`)
- Network interface: `eth0` (virtio-net)
- IP: `192.168.1.21/24` (VM IP, not host IP .11)
- Hostname: `talos-cp-1`
- DNS servers: `192.168.1.5` (Pi-hole on Synology)
- VIP: `192.168.1.20` (K8s API VIP)
- Allow scheduling on control plane (hybrid mode)

**For Workers (`worker.yaml`):**

```bash
# Create worker-2.yaml
cp worker.yaml worker-2.yaml
nano worker-2.yaml
# Set IP: 192.168.1.22/24, hostname: talos-worker-2

# Create worker-3.yaml
cp worker.yaml worker-3.yaml
nano worker-3.yaml
# Set IP: 192.168.1.23/24, hostname: talos-worker-3
```

### 4. Start VMs and Apply Configurations

```bash
# Start VMs (from Proxmox host or web UI)
qm start 100  # Control plane
qm start 101  # Worker 2
qm start 102  # Worker 3

# Wait for VMs to boot and get DHCP IPs
# Check Proxmox console for each VM's temporary DHCP IP

# Apply to control plane VM
talosctl apply-config --insecure \
  --nodes <vm-100-dhcp-ip> \
  --file controlplane.yaml

# Wait 2-3 minutes, then apply to workers
talosctl apply-config --insecure \
  --nodes <vm-101-dhcp-ip> \
  --file worker-2.yaml

talosctl apply-config --insecure \
  --nodes <vm-102-dhcp-ip> \
  --file worker-3.yaml
```

### 5. Configure talosctl

```bash
# Set the endpoints and nodes (using static VM IPs now)
export TALOSCONFIG=$(pwd)/talosconfig
talosctl config endpoint 192.168.1.21
talosctl config node 192.168.1.21

# Add to your shell profile
echo 'export TALOSCONFIG=/path/to/synology_containers/talos/talosconfig' >> ~/.bashrc
```

### 6. Bootstrap Kubernetes

```bash
# Bootstrap the cluster (only on control plane, only once!)
talosctl bootstrap --nodes 192.168.1.21

# Wait 3-5 minutes for control plane to initialize
```

### 7. Get kubeconfig

```bash
# Generate kubeconfig
talosctl kubeconfig .

# Configure kubectl
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes

# Expected output:
# NAME            STATUS   ROLES           AGE   VERSION
# talos-cp-1      Ready    control-plane   5m    v1.29.x
# talos-worker-2  Ready    <none>          3m    v1.29.x
# talos-worker-3  Ready    <none>          3m    v1.29.x
```

### 8. Post-Installation (Proxmox)

```bash
# Remove ISO from VMs
qm set 100 --ide2 none
qm set 101 --ide2 none
qm set 102 --ide2 none

# Set boot order to disk
qm set 100 --boot order=scsi0
qm set 101 --boot order=scsi0
qm set 102 --boot order=scsi0

# Add VMs to Proxmox HA (optional)
ha-manager add vm:100 --group talos-vms --state started
ha-manager add vm:101 --group talos-vms --state started
ha-manager add vm:102 --group talos-vms --state started
```

## File Descriptions

| File | Description | Commit to Git? |
|------|-------------|----------------|
| `controlplane.yaml.example` | Template for control plane config | Yes |
| `worker.yaml.example` | Template for worker config | Yes |
| `controlplane.yaml` | **Actual control plane config** | **NO!** |
| `worker.yaml` | **Actual worker config** | **NO!** |
| `worker-2.yaml` | **Actual worker-2 config** | **NO!** |
| `worker-3.yaml` | **Actual worker-3 config** | **NO!** |
| `talosconfig` | **talosctl client config** | **NO!** |
| `kubeconfig` | **kubectl client config** | **NO!** |
| `.gitignore` | Prevents committing secrets | Yes |
| `README.md` | This file | Yes |

## Network Configuration Reference

### IP Allocations (Proxmox + Talos VMs)

| Resource | IP Address | Purpose |
|----------|------------|---------|
| **Proxmox Hosts** | | |
| pve1 (Beelink #1) | `192.168.1.11` | Hypervisor |
| pve2 (Beelink #2) | `192.168.1.12` | Hypervisor |
| pve3 (Beelink #3) | `192.168.1.13` | Hypervisor |
| **Talos VMs** | | |
| talos-cp-1 (VM 100) | `192.168.1.21` | K8s control plane + worker |
| talos-worker-2 (VM 101) | `192.168.1.22` | K8s worker |
| talos-worker-3 (VM 102) | `192.168.1.23` | K8s worker |
| **Services** | | |
| Kubernetes API VIP | `192.168.1.20` | K8s API endpoint |
| Synology NAS | `192.168.1.5` | Storage, DNS, Docker |
| Router/Gateway | `192.168.1.1` | Default gateway |

### Network Ranges

| Network | CIDR | Purpose |
|---------|------|---------|
| Host/VM Network | `192.168.1.0/24` | Physical hosts + VMs |
| Pod Network | `10.244.0.0/16` | Kubernetes pod IPs (Cilium) |
| Service Network | `10.96.0.0/12` | Kubernetes service IPs |
| MetalLB Pool | `192.168.1.210-220` | LoadBalancer service IPs |

### Disk Device Reference (Proxmox VMs)

| Environment | Boot Disk | Notes |
|-------------|-----------|-------|
| Proxmox VM (virtio) | `/dev/vda` | Default for VMs |
| Bare metal (NVMe) | `/dev/nvme0n1` | Direct hardware |
| Bare metal (SATA) | `/dev/sda` | SATA drives |

## Common Operations

### Check Cluster Health

```bash
# Talos health (all 3 VMs)
talosctl health --nodes 192.168.1.21,192.168.1.22,192.168.1.23

# Kubernetes health
kubectl get nodes -o wide
kubectl get pods -A
```

### View Logs

```bash
# Talos system logs
talosctl dmesg --nodes 192.168.1.21
talosctl logs --nodes 192.168.1.21

# Specific service logs
talosctl logs kubelet --nodes 192.168.1.21
talosctl logs etcd --nodes 192.168.1.21
```

### Reboot VMs (via Talos)

```bash
# Graceful reboot
talosctl reboot --nodes 192.168.1.21

# Emergency reboot
talosctl reboot --nodes 192.168.1.21 --force
```

### Reboot VMs (via Proxmox)

```bash
# From Proxmox host
qm reboot 100  # Graceful
qm stop 100 && qm start 100  # Hard restart
```

### Upgrade Talos

```bash
# Check current version
talosctl version --nodes 192.168.1.21

# Upgrade (example to v1.9.0)
talosctl upgrade --nodes 192.168.1.21 \
  --image ghcr.io/siderolabs/installer:v1.9.0

# Upgrade preserves configuration
```

### Upgrade Kubernetes

```bash
# Upgrade control plane first
talosctl upgrade-k8s --nodes 192.168.1.21 --to 1.29.2

# Rolling upgrade ensures zero downtime
```

### VM Snapshots (Proxmox)

```bash
# Create snapshot before major changes
qm snapshot 100 pre-upgrade --description "Before K8s upgrade"

# Restore if something goes wrong
qm rollback 100 pre-upgrade
```

### Reset/Wipe Node

```bash
# Reset node (WARNING: destroys all data!)
talosctl reset --nodes 192.168.1.23 --graceful

# Complete wipe (including etcd data)
talosctl reset --nodes 192.168.1.23 --graceful --wipe-mode all
```

## Backup Strategy

### Backup Configuration Files

```bash
# Create encrypted backup of configurations
tar czf talos-configs-$(date +%Y%m%d).tar.gz \
  controlplane.yaml worker-2.yaml worker-3.yaml talosconfig kubeconfig

# Encrypt with GPG
gpg -c talos-configs-$(date +%Y%m%d).tar.gz

# Store encrypted file in secure location (NOT in Git!)
```

### etcd Backup

```bash
# Take etcd snapshot
talosctl etcd snapshot --nodes 192.168.1.21 etcd-snapshot.db

# Store on Synology
scp etcd-snapshot.db admin@192.168.1.5:/volume1/k8s-backups/
```

### VM Backup (Proxmox)

```bash
# Full VM backup via vzdump
vzdump 100 101 102 --storage nas-backup --mode snapshot --compress zstd
```

## Troubleshooting

### VM Won't Boot

1. Check VM console via Proxmox web UI
2. Verify ISO is attached correctly
3. Check boot order (IDE2/CD first for install, SCSI0 after)
4. Verify VM resources (RAM, CPU)

### Can't Apply Configuration

```bash
# Check VM connectivity (use DHCP IP during install)
ping <vm-dhcp-ip>

# Verify talosctl can reach VM
talosctl version --nodes <vm-dhcp-ip> --insecure

# Check configuration syntax
talosctl validate --config controlplane.yaml
```

### Cluster Won't Bootstrap

```bash
# Check if etcd is running
talosctl service etcd status --nodes 192.168.1.21

# View etcd logs
talosctl logs etcd --nodes 192.168.1.21 --follow

# Check disk device (should be /dev/vda for VMs)
talosctl disks --nodes 192.168.1.21
```

### Worker Won't Join

```bash
# Check control plane endpoint
talosctl get members --nodes 192.168.1.21

# Verify worker can reach control plane
talosctl get kubeconfig --nodes 192.168.1.22

# Check kubelet logs on worker
talosctl logs kubelet --nodes 192.168.1.22 --follow
```

## Additional Resources

- **Proxmox Documentation**: https://pve.proxmox.com/pve-docs/
- **Talos Documentation**: https://www.talos.dev/
- **Configuration Reference**: https://www.talos.dev/v1.9/reference/configuration/
- **API Documentation**: https://www.talos.dev/v1.9/reference/api/
- **Talos GitHub**: https://github.com/siderolabs/talos

---

**Last Updated**: 2025-12-09

---

[Back to Main README](../README.md) | [Proxmox Setup](../docs/PROXMOX_SETUP.md) | [K8s Architecture](../docs/K8S_ARCHITECTURE.md)
