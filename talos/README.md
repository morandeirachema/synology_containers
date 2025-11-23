# Talos Configuration Files

This directory contains Talos Linux configuration files for your Kubernetes cluster.

## ⚠️ Security Warning

**NEVER commit the actual configuration files (`controlplane.yaml`, `worker.yaml`, `talosconfig`) to Git!**

These files contain:
- Cluster secrets and tokens
- Certificate private keys
- API credentials

Only the `.example` template files should be in version control.

## Quick Start

### 1. Generate Initial Configurations

```bash
cd talos

# Generate base configurations
talosctl gen config my-cluster https://192.168.1.200:6443 \
  --output-dir .
```

This creates:
- `controlplane.yaml` - Control plane node configuration
- `worker.yaml` - Worker node configuration
- `talosconfig` - Client configuration for talosctl

### 2. Customize Configurations

The generated files need customization. Use the `.example` files as reference:

**For Control Plane (`controlplane.yaml`):**

```bash
# Copy the generated file as backup
cp controlplane.yaml controlplane.yaml.bak

# Edit the configuration
nano controlplane.yaml
```

Key changes needed:
- Network configuration (IP: `192.168.1.201`)
- Hostname (`talos-cp-1`)
- DNS servers (Pi-hole: `192.168.1.100`)
- VIP for API server (`192.168.1.200`)
- Install disk (`/dev/nvme0n1`)
- Allow scheduling on control plane (hybrid mode)

**For Worker (`worker.yaml`):**

```bash
# Copy the generated file as backup
cp worker.yaml worker.yaml.bak

# Edit the configuration
nano worker.yaml
```

Key changes needed:
- Network configuration (IP: `192.168.1.202`)
- Hostname (`talos-worker-1`)
- DNS servers
- Control plane endpoint (VIP: `https://192.168.1.200:6443`)

### 3. Apply Configurations

**First, boot Talos from USB on both nodes**, then:

```bash
# Apply to control plane (use DHCP IP from boot)
talosctl apply-config --insecure \
  --nodes <control-plane-dhcp-ip> \
  --file controlplane.yaml

# Wait 2-3 minutes, then apply to worker
talosctl apply-config --insecure \
  --nodes <worker-dhcp-ip> \
  --file worker.yaml
```

### 4. Configure talosctl

```bash
# Set the endpoints and nodes
export TALOSCONFIG=$(pwd)/talosconfig
talosctl config endpoint 192.168.1.201
talosctl config node 192.168.1.201

# Add to your shell profile
echo 'export TALOSCONFIG=/path/to/synology_containers/talos/talosconfig' >> ~/.bashrc
# or ~/.zshrc
```

### 5. Bootstrap Kubernetes

```bash
# Bootstrap the cluster (only on control plane, only once!)
talosctl bootstrap --nodes 192.168.1.201

# Wait 3-5 minutes for control plane to initialize
```

### 6. Get kubeconfig

```bash
# Generate kubeconfig
talosctl kubeconfig .

# Configure kubectl
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes

# Add to your shell profile
echo 'export KUBECONFIG=/path/to/synology_containers/talos/kubeconfig' >> ~/.bashrc
```

## File Descriptions

| File | Description | Commit to Git? |
|------|-------------|----------------|
| `controlplane.yaml.example` | Template for control plane config | ✅ Yes |
| `worker.yaml.example` | Template for worker config | ✅ Yes |
| `controlplane.yaml` | **Actual control plane config** | ❌ **NO!** |
| `worker.yaml` | **Actual worker config** | ❌ **NO!** |
| `talosconfig` | **talosctl client config** | ❌ **NO!** |
| `kubeconfig` | **kubectl client config** | ❌ **NO!** |
| `.gitignore` | Prevents committing secrets | ✅ Yes |
| `README.md` | This file | ✅ Yes |

## Network Configuration Reference

### IP Allocations

| Resource | IP Address | Purpose |
|----------|------------|---------|
| Control Plane | `192.168.1.201` | Talos node + K8s control plane |
| Worker | `192.168.1.202` | Talos worker node |
| Kubernetes API VIP | `192.168.1.200` | Virtual IP for HA API access |
| Synology NAS | `192.168.1.100` | Storage, DNS, Docker stack |
| Router/Gateway | `192.168.1.1` | Default gateway |

### Network Ranges

| Network | CIDR | Purpose |
|---------|------|---------|
| Node Network | `192.168.1.0/24` | Physical node IPs |
| Pod Network | `10.244.0.0/16` | Kubernetes pod IPs (Cilium) |
| Service Network | `10.96.0.0/12` | Kubernetes service IPs |
| MetalLB Pool | `192.168.1.210-220` | LoadBalancer service IPs |

## Common Operations

### Check Cluster Health

```bash
# Talos health
talosctl health --nodes 192.168.1.201,192.168.1.202

# Kubernetes health
kubectl get nodes -o wide
kubectl get pods -A
```

### View Logs

```bash
# Talos system logs
talosctl dmesg --nodes 192.168.1.201
talosctl logs --nodes 192.168.1.201

# Specific service logs
talosctl logs kubelet --nodes 192.168.1.201
talosctl logs etcd --nodes 192.168.1.201
```

### Reboot Nodes

```bash
# Graceful reboot
talosctl reboot --nodes 192.168.1.201

# Emergency reboot
talosctl reboot --nodes 192.168.1.201 --force
```

### Upgrade Talos

```bash
# Check current version
talosctl version --nodes 192.168.1.201

# Upgrade (example to v1.6.4)
talosctl upgrade --nodes 192.168.1.201 \
  --image ghcr.io/siderolabs/installer:v1.6.4

# Upgrade preserves configuration
```

### Upgrade Kubernetes

```bash
# Upgrade control plane
talosctl upgrade-k8s --nodes 192.168.1.201 --to 1.29.2

# Rolling upgrade ensures zero downtime
```

### Edit Configuration

```bash
# Generate patch
talosctl gen config --output-dir /tmp my-cluster https://192.168.1.200:6443

# Edit the generated file, then apply
talosctl apply-config --nodes 192.168.1.201 \
  --file /tmp/controlplane.yaml

# Or patch specific values
talosctl patch machineconfig --nodes 192.168.1.201 \
  --patch '[{"op": "add", "path": "/machine/network/hostname", "value": "new-hostname"}]'
```

### Reset/Wipe Node

```bash
# Reset node (WARNING: destroys all data!)
talosctl reset --nodes 192.168.1.202 --graceful

# Complete wipe (including etcd data)
talosctl reset --nodes 192.168.1.202 --graceful --wipe-mode all
```

## Configuration Differences

### Control Plane vs Worker

**Control Plane (`type: controlplane`):**
- Runs etcd (distributed database)
- Runs Kubernetes control plane components:
  - kube-apiserver
  - kube-scheduler
  - kube-controller-manager
- Can run workloads (if `allowSchedulingOnControlPlanes: true`)
- Has VIP configuration for HA

**Worker (`type: worker`):**
- Runs only workload pods
- Connects to control plane API
- Does NOT run etcd or control plane components
- Optimized for application workloads

### Hybrid vs Dedicated Control Plane

**Hybrid Mode** (our setup):
```yaml
cluster:
  allowSchedulingOnControlPlanes: true
```
- Control plane also runs workloads
- Efficient for small clusters (2-3 nodes)
- Still maintains separation via taints/tolerations

**Dedicated Mode** (production HA):
```yaml
cluster:
  allowSchedulingOnControlPlanes: false
```
- Control plane nodes run ONLY control plane
- Requires more hardware (3 control plane + N workers)
- Better for large production clusters

## Backup Strategy

### Backup Configuration Files

```bash
# Create encrypted backup of configurations
tar czf talos-configs-$(date +%Y%m%d).tar.gz \
  controlplane.yaml worker.yaml talosconfig kubeconfig

# Encrypt with GPG
gpg -c talos-configs-$(date +%Y%m%d).tar.gz

# Store encrypted file in secure location (NOT in Git!)
```

### etcd Backup

Talos automatically backs up etcd. Manual snapshot:

```bash
# Take etcd snapshot
talosctl etcd snapshot --nodes 192.168.1.201 etcd-snapshot.db

# Store on Synology
scp etcd-snapshot.db admin@192.168.1.100:/volume1/k8s-backups/
```

## Troubleshooting

### Node Won't Boot

1. Check boot order in BIOS (USB/NVMe)
2. Verify Talos ISO integrity
3. Check DHCP assignment
4. View console logs

### Can't Apply Configuration

```bash
# Check node connectivity
ping 192.168.1.201

# Verify talosctl can reach node
talosctl version --nodes 192.168.1.201 --insecure

# Check configuration syntax
talosctl validate --config controlplane.yaml
```

### Cluster Won't Bootstrap

```bash
# Check if etcd is running
talosctl service etcd status --nodes 192.168.1.201

# View etcd logs
talosctl logs etcd --nodes 192.168.1.201 --follow

# Restart etcd service
talosctl service etcd restart --nodes 192.168.1.201
```

### Worker Won't Join

```bash
# Check control plane endpoint
talosctl get members --nodes 192.168.1.201

# Verify worker can reach control plane
talosctl get kubeconfig --nodes 192.168.1.202

# Check kubelet logs on worker
talosctl logs kubelet --nodes 192.168.1.202 --follow
```

## Additional Resources

- **Talos Documentation**: https://www.talos.dev/
- **Configuration Reference**: https://www.talos.dev/v1.6/reference/configuration/
- **API Documentation**: https://www.talos.dev/v1.6/reference/api/
- **GitHub**: https://github.com/siderolabs/talos
- **Community**: https://slack.dev.talos-systems.io/

---

[Back to Main README](../README.md) | [Setup Guide](../docs/TALOS_KUBERNETES_SETUP.md) | [Architecture](../docs/K8S_ARCHITECTURE.md)
