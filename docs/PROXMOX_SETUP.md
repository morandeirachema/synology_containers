# Proxmox VE Setup Guide

Complete guide for installing and configuring Proxmox VE on Beelink Mini S13 nodes to host Talos Linux virtual machines for Kubernetes.

**Last Updated:** 2025-12-09

---

## Table of Contents

1. [Overview](#overview)
2. [Hardware Requirements](#hardware-requirements)
3. [Network Architecture](#network-architecture)
4. [BIOS Configuration](#bios-configuration)
5. [Proxmox Installation](#proxmox-installation)
6. [Post-Installation Configuration](#post-installation-configuration)
7. [Network Bridge Setup](#network-bridge-setup)
8. [Storage Configuration](#storage-configuration)
9. [Proxmox Cluster Formation](#proxmox-cluster-formation)
10. [High Availability Configuration](#high-availability-configuration)
11. [Creating Talos VMs](#creating-talos-vms)
12. [Backup Configuration](#backup-configuration)
13. [Maintenance Operations](#maintenance-operations)
14. [Troubleshooting](#troubleshooting)
15. [References](#references)

---

## Overview

This guide covers the virtualization layer for our Kubernetes homelab. Instead of running Talos Linux directly on bare metal, we use Proxmox VE as a hypervisor to gain flexibility, snapshots, and high availability features.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           HOMELAB INFRASTRUCTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐ │
│  │   Beelink S13 #1    │  │   Beelink S13 #2    │  │   Beelink S13 #3    │ │
│  │   192.168.1.11      │  │   192.168.1.12      │  │   192.168.1.13      │ │
│  ├─────────────────────┤  ├─────────────────────┤  ├─────────────────────┤ │
│  │   Proxmox VE 9.x    │  │   Proxmox VE 9.x    │  │   Proxmox VE 9.x    │ │
│  │  ┌───────────────┐  │  │  ┌───────────────┐  │  │  ┌───────────────┐  │ │
│  │  │ Talos VM      │  │  │  │ Talos VM      │  │  │  │ Talos VM      │  │ │
│  │  │ 192.168.1.21  │  │  │  │ 192.168.1.22  │  │  │  │ 192.168.1.23  │  │ │
│  │  │ 12GB/3vCPU    │  │  │  │ 12GB/3vCPU    │  │  │  │ 12GB/3vCPU    │  │ │
│  │  │ Control+Work  │  │  │  │ Worker        │  │  │  │ Worker        │  │ │
│  │  └───────────────┘  │  │  └───────────────┘  │  │  └───────────────┘  │ │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘ │
│                                    │                                        │
│                    ┌───────────────┴───────────────┐                       │
│                    │      Kubernetes API VIP       │                       │
│                    │        192.168.1.20           │                       │
│                    └───────────────┬───────────────┘                       │
│                                    │                                        │
│                    ┌───────────────┴───────────────┐                       │
│                    │     Synology NAS (NFS)        │                       │
│                    │        192.168.1.5            │                       │
│                    └───────────────────────────────┘                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Benefits of Virtualization

| Feature | Bare Metal | Proxmox VMs |
|---------|------------|-------------|
| Snapshots | No | Yes - instant rollback |
| Live Migration | No | Yes - move VMs between hosts |
| Resource Flexibility | Fixed | Dynamic allocation |
| Multiple OS | No | Yes - run different workloads |
| Backup | OS-level only | Full VM backup with vzdump |
| Recovery Time | Re-install OS | Restore from backup in minutes |
| High Availability | Manual failover | Automatic VM restart |

---

## Hardware Requirements

### Beelink Mini S13 Specifications

| Component | Specification | Notes |
|-----------|--------------|-------|
| **Model** | Beelink Mini S13 | 3 units required |
| **CPU** | Intel N150 (4 cores, 4 threads) | Supports VT-x, VT-d |
| **RAM** | 16GB DDR4 | 12GB for VM, 4GB for Proxmox |
| **Storage** | 512GB NVMe | ~100GB for VM, rest for local storage |
| **Network** | 1x 1Gbps Ethernet | Connected to same switch |
| **Power** | ~15W TDP | Low power consumption |

### Minimum Requirements per Node

- **CPU:** Intel/AMD with VT-x/AMD-V virtualization
- **RAM:** 16GB minimum (12GB VM + 4GB host)
- **Storage:** 256GB minimum NVMe/SSD
- **Network:** Gigabit Ethernet

### Network Infrastructure

| Device | IP Address | Purpose |
|--------|------------|---------|
| Router/Gateway | 192.168.1.1 | Default gateway, DHCP |
| Synology NAS | 192.168.1.5 | NFS storage, backups |
| Proxmox Node 1 | 192.168.1.11 | Hypervisor host |
| Proxmox Node 2 | 192.168.1.12 | Hypervisor host |
| Proxmox Node 3 | 192.168.1.13 | Hypervisor host |
| Talos VM 1 | 192.168.1.21 | K8s control-plane + worker |
| Talos VM 2 | 192.168.1.22 | K8s worker |
| Talos VM 3 | 192.168.1.23 | K8s worker |
| K8s API VIP | 192.168.1.20 | Kubernetes API endpoint |
| MetalLB Pool | 192.168.1.210-220 | LoadBalancer services |

---

## Network Architecture

### Physical Network

```
┌─────────────────────────────────────────────────────────────────┐
│                     Network Switch (1Gbps)                      │
├─────────┬─────────┬─────────┬─────────┬─────────┬──────────────┤
│ Port 1  │ Port 2  │ Port 3  │ Port 4  │ Port 5  │ Port 6       │
│ Router  │ NAS     │ Node 1  │ Node 2  │ Node 3  │ Workstation  │
│ .1      │ .5      │ .11     │ .12     │ .13     │ DHCP         │
└─────────┴─────────┴─────────┴─────────┴─────────┴──────────────┘
```

### Virtual Network (Per Proxmox Host)

```
┌─────────────────────────────────────────────────────────┐
│                    Proxmox Host                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Physical NIC (enp1s0)                                 │
│         │                                               │
│         ▼                                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │           Linux Bridge (vmbr0)                   │   │
│  │           192.168.1.x/24                         │   │
│  ├─────────────────────────────────────────────────┤   │
│  │                    │                             │   │
│  │         ┌──────────┴──────────┐                 │   │
│  │         ▼                     ▼                 │   │
│  │   Proxmox Host IP       VM: Talos              │   │
│  │   192.168.1.1x          192.168.1.2x           │   │
│  │                         (virtio-net)            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## BIOS Configuration

Before installing Proxmox, configure the BIOS on each Beelink Mini S13.

### Accessing BIOS

1. Connect monitor and keyboard to Beelink
2. Power on and press **DEL** or **F2** repeatedly
3. Enter BIOS Setup

### Required Settings

| Setting | Location | Value | Purpose |
|---------|----------|-------|---------|
| **Intel VT-x** | Advanced > CPU | Enabled | Hardware virtualization |
| **Intel VT-d** | Advanced > CPU | Enabled | IOMMU for passthrough |
| **Hyper-Threading** | Advanced > CPU | Enabled | More threads available |
| **Boot Mode** | Boot | UEFI | Required for Proxmox |
| **Secure Boot** | Security | Disabled | Proxmox compatibility |
| **Wake on LAN** | Advanced > Network | Enabled | Remote power on |

### Boot Order

Set boot order for installation:
1. USB Drive (for Proxmox installer)
2. NVMe SSD (primary boot after install)

### Save and Exit

Press **F10** to save and exit BIOS.

---

## Proxmox Installation

### Download Proxmox VE ISO

1. Visit: https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso
2. Download latest Proxmox VE 9.x ISO
3. Verify SHA256 checksum

### Create Bootable USB

**On Linux/macOS:**
```bash
# Identify USB device (be careful!)
lsblk

# Write ISO to USB (replace /dev/sdX with your device)
sudo dd if=proxmox-ve_9.x.iso of=/dev/sdX bs=4M status=progress
sync
```

**On Windows:**
- Use [Rufus](https://rufus.ie/) or [balenaEtcher](https://etcher.balena.io/)
- Select ISO and USB drive
- Write in DD mode

### Installation Steps

Repeat these steps for each of the 3 Beelink nodes:

#### Step 1: Boot from USB

1. Insert USB into Beelink
2. Power on and press **F7** for boot menu
3. Select USB drive
4. Choose "Install Proxmox VE (Graphical)"

#### Step 2: Accept License

- Read and accept the EULA
- Click "I agree"

#### Step 3: Select Target Disk

- Select the NVMe drive (typically `nvme0n1`)
- **Options** (click to configure):
  - Filesystem: **ext4** (or zfs for advanced users)
  - hdsize: Leave default (use full disk)
  - swapsize: **4** GB
  - maxvz: Leave default

#### Step 4: Location and Timezone

- Country: Your country
- Timezone: Your timezone
- Keyboard: Your layout

#### Step 5: Administration Password

- Password: Strong password (save in password manager)
- Email: Your email for alerts

#### Step 6: Network Configuration

**For Node 1:**
| Field | Value |
|-------|-------|
| Management Interface | enp1s0 (or detected NIC) |
| Hostname (FQDN) | pve1.homelab.local |
| IP Address | 192.168.1.11/24 |
| Gateway | 192.168.1.1 |
| DNS Server | 192.168.1.1 (or Pi-hole) |

**For Node 2:**
- Hostname: pve2.homelab.local
- IP: 192.168.1.12/24

**For Node 3:**
- Hostname: pve3.homelab.local
- IP: 192.168.1.13/24

#### Step 7: Review and Install

- Review all settings
- Click "Install"
- Wait for installation (5-10 minutes)
- Remove USB when prompted
- Reboot

### Post-Installation Access

After reboot, access Proxmox web UI:

| Node | URL |
|------|-----|
| Node 1 | https://192.168.1.11:8006 |
| Node 2 | https://192.168.1.12:8006 |
| Node 3 | https://192.168.1.13:8006 |

Login credentials:
- Username: `root`
- Password: (set during installation)

---

## Post-Installation Configuration

Perform these steps on each Proxmox node via SSH or web shell.

### 1. Update Package Repositories

Remove enterprise repository (requires subscription) and add no-subscription repository:

```bash
# Disable enterprise repository
mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.disabled

# Add no-subscription repository
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Update and upgrade
apt update && apt full-upgrade -y
```

### 2. Remove Subscription Nag (Optional)

```bash
# Backup original file
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak

# Remove subscription notice
sed -i.bak "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# Restart web service
systemctl restart pveproxy
```

### 3. Configure NTP

Ensure time synchronization across all nodes:

```bash
# Install chrony if not present
apt install chrony -y

# Configure NTP servers (edit /etc/chrony/chrony.conf)
cat >> /etc/chrony/chrony.conf << 'EOF'
# Local NTP servers
server 192.168.1.1 iburst
server time.google.com iburst
server time.cloudflare.com iburst
EOF

# Restart chrony
systemctl restart chrony

# Verify synchronization
chronyc tracking
```

### 4. Configure Email Alerts (Optional)

```bash
# Install mail utilities
apt install libsasl2-modules mailutils -y

# Configure postfix for Gmail relay (example)
# Edit /etc/postfix/main.cf and add:
# relayhost = [smtp.gmail.com]:587
# smtp_sasl_auth_enable = yes
# smtp_sasl_security_options = noanonymous
# smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
# smtp_tls_security_level = encrypt
# smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
```

### 5. Install Useful Tools

```bash
apt install -y \
  htop \
  iotop \
  net-tools \
  vim \
  curl \
  wget \
  tmux
```

---

## Network Bridge Setup

The default installation creates `vmbr0`. Verify and configure it properly.

### Verify Network Configuration

```bash
# Check current network config
cat /etc/network/interfaces
```

### Expected Configuration

```
auto lo
iface lo inet loopback

iface enp1s0 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.1.11/24
    gateway 192.168.1.1
    bridge-ports enp1s0
    bridge-stp off
    bridge-fd 0
```

### Apply Network Changes

If you modify `/etc/network/interfaces`:

```bash
# Restart networking (may disconnect SSH!)
systemctl restart networking

# Or reboot for safety
reboot
```

### Verify Bridge

```bash
# Check bridge status
brctl show

# Expected output:
# bridge name    bridge id          STP enabled    interfaces
# vmbr0          8000.xxxxxxxxxxxx  no             enp1s0

# Verify IP assignment
ip addr show vmbr0
```

---

## Storage Configuration

### Local Storage

Proxmox creates default local storage during installation.

**View storage in Web UI:**
- Datacenter → Storage

**Default storage:**

| Storage | Type | Content | Path |
|---------|------|---------|------|
| local | Directory | ISO, Templates | /var/lib/vz |
| local-lvm | LVM-Thin | VM Disks, Containers | pve/data |

### Add NFS Storage (Synology NAS)

#### On Synology NAS

1. Open **Control Panel** → **Shared Folder**
2. Create shared folders:
   - `proxmox-backup` - For VM backups
   - `proxmox-iso` - For ISO images
3. Open **Control Panel** → **File Services** → **NFS**
4. Enable NFS service
5. Set NFS permissions for each folder:
   - Hostname: `192.168.1.0/24`
   - Privilege: Read/Write
   - Squash: Map all users to admin
   - Security: sys
   - Enable async: Yes

#### On Proxmox (Any Node - Shared Across Cluster)

**Via Web UI:**
1. Datacenter → Storage → Add → NFS
2. Configure:
   - ID: `nas-backup`
   - Server: `192.168.1.5`
   - Export: `/volume1/proxmox-backup`
   - Content: VZDump backup file
   - Nodes: All
   - Enable: Yes

3. Add another for ISOs:
   - ID: `nas-iso`
   - Server: `192.168.1.5`
   - Export: `/volume1/proxmox-iso`
   - Content: ISO image, Container template

**Via CLI:**
```bash
# Add NFS storage for backups
pvesm add nfs nas-backup \
  --server 192.168.1.5 \
  --export /volume1/proxmox-backup \
  --content backup \
  --options vers=4.1

# Add NFS storage for ISOs
pvesm add nfs nas-iso \
  --server 192.168.1.5 \
  --export /volume1/proxmox-iso \
  --content iso,vztmpl \
  --options vers=4.1
```

### Upload Talos ISO

1. Download Talos ISO: https://github.com/siderolabs/talos/releases
   - File: `talos-amd64.iso`
2. Upload to Proxmox:
   - Web UI: nas-iso (or local) → ISO Images → Upload
   - Or via CLI:
     ```bash
     wget -P /var/lib/vz/template/iso/ \
       https://github.com/siderolabs/talos/releases/download/v1.9.0/talos-amd64.iso
     ```

---

## Proxmox Cluster Formation

A 3-node Proxmox cluster provides shared configuration and enables High Availability.

### Prerequisites

- All nodes have unique hostnames
- All nodes can reach each other on the network
- Time is synchronized across all nodes
- No VMs created yet (or prepared for cluster join)

### Create Cluster (Node 1)

On **pve1** (192.168.1.11):

**Via Web UI:**
1. Datacenter → Cluster → Create Cluster
2. Cluster Name: `homelab-cluster`
3. Click "Create"
4. Wait for completion

**Via CLI:**
```bash
pvecm create homelab-cluster
```

### Get Join Information

On **pve1**:

**Via Web UI:**
1. Datacenter → Cluster → Join Information
2. Copy the join information

**Via CLI:**
```bash
pvecm status
# Note the cluster fingerprint and join address
```

### Join Cluster (Node 2 and 3)

On **pve2** (192.168.1.12):

**Via Web UI:**
1. Datacenter → Cluster → Join Cluster
2. Paste join information from Node 1
3. Enter root password for Node 1
4. Click "Join"
5. Wait for completion (node will disconnect briefly)

**Via CLI:**
```bash
pvecm add 192.168.1.11
# Enter password when prompted
```

Repeat for **pve3** (192.168.1.13).

### Verify Cluster Status

```bash
# Check cluster status
pvecm status

# Expected output shows 3 nodes:
# Cluster information
# -------------------
# Name:             homelab-cluster
# Config Version:   3
# Transport:        knet
# Secure auth:      on
#
# Quorum information
# ------------------
# Date:             ...
# Quorum provider:  corosync_votequorum
# Nodes:            3
# Node ID:          0x00000001
# Ring ID:          1.xxx
# Quorate:          Yes

# Check node list
pvecm nodes

# Expected output:
# Membership information
# ----------------------
#     Nodeid      Votes Name
#          1          1 pve1 (local)
#          2          1 pve2
#          3          1 pve3
```

### Cluster Web UI

After clustering, you can manage all nodes from any node's web UI:
- https://192.168.1.11:8006 (or .12, .13)
- All nodes appear under "Datacenter"

---

## High Availability Configuration

Proxmox HA automatically restarts VMs on healthy nodes if a host fails.

### Prerequisites for HA

- 3-node cluster (for quorum)
- Shared storage (NFS from NAS) for VM configurations
- Fencing configured (optional but recommended)

### Enable HA Manager

HA is enabled by default in clustered Proxmox. Verify:

```bash
# Check HA status
ha-manager status
```

### Configure Fencing (Watchdog)

Fencing ensures a failed node is truly down before restarting its VMs elsewhere.

**Software Watchdog (Default):**
```bash
# Check watchdog status
cat /etc/default/pve-ha-manager

# Should contain:
# WATCHDOG_MODULE=softdog
```

**Enable Hardware Watchdog (if available):**
```bash
# Check for hardware watchdog
ls -la /dev/watchdog*

# Configure in /etc/default/pve-ha-manager:
# WATCHDOG_MODULE=iTCO_wdt  # Intel watchdog
```

### Create HA Group

Group VMs for HA management:

**Via Web UI:**
1. Datacenter → HA → Groups → Create
2. Configure:
   - Group: `talos-vms`
   - Nodes: pve1, pve2, pve3
   - restricted: No
   - nofailback: No

**Via CLI:**
```bash
ha-manager groupadd talos-vms --nodes pve1,pve2,pve3
```

### Add VM to HA

After creating VMs (covered later), add them to HA:

**Via Web UI:**
1. Datacenter → HA → Resources → Add
2. Configure:
   - VM: Select Talos VM
   - Group: talos-vms
   - Max Restart: 3
   - Max Relocate: 3
   - State: started

**Via CLI:**
```bash
# Add VM 100 to HA
ha-manager add vm:100 --group talos-vms --state started
```

### HA States

| State | Description |
|-------|-------------|
| started | VM should be running, auto-restart on failure |
| stopped | VM should be stopped |
| disabled | HA disabled for this VM |
| ignored | VM managed manually |

### Test HA Failover

**WARNING: This will cause VM downtime!**

```bash
# On the node running a Talos VM, simulate failure:
echo c > /proc/sysrq-trigger  # Kernel crash (DANGEROUS!)

# Safer test - stop pve-ha-lrm service:
systemctl stop pve-ha-lrm
# Wait 60 seconds, VMs should migrate
systemctl start pve-ha-lrm
```

### Monitor HA Status

```bash
# View HA status
ha-manager status

# View HA logs
journalctl -u pve-ha-lrm -f

# Web UI: Datacenter → HA → Status
```

---

## Creating Talos VMs

Create one Talos VM per Proxmox host for optimal HA.

### VM Specifications

| Setting | Value | Notes |
|---------|-------|-------|
| VM ID | 100, 101, 102 | One per node |
| Name | talos-cp-1, talos-worker-2, talos-worker-3 | Descriptive names |
| CPU | 3 cores | Host CPU type |
| RAM | 12288 MB (12GB) | Fixed, no ballooning |
| Disk | 100 GB | virtio-scsi |
| Network | virtio on vmbr0 | DHCP or static |
| Machine | q35 | Modern chipset |
| BIOS | OVMF (UEFI) | Or SeaBIOS |

### Create VM (Web UI)

**On pve1 - Create talos-cp-1:**

1. **Click "Create VM"**

2. **General Tab:**
   - Node: pve1
   - VM ID: 100
   - Name: talos-cp-1

3. **OS Tab:**
   - Use CD/DVD: Yes
   - Storage: nas-iso (or local)
   - ISO image: talos-amd64.iso
   - Guest OS Type: Linux
   - Version: 6.x - 2.6 Kernel

4. **System Tab:**
   - Machine: q35
   - BIOS: OVMF (UEFI)
   - Add EFI Disk: Yes
   - EFI Storage: local-lvm
   - SCSI Controller: VirtIO SCSI single
   - Qemu Agent: No (Talos doesn't support)

5. **Disks Tab:**
   - Bus/Device: SCSI (virtio-scsi)
   - Storage: local-lvm
   - Disk size: 100 GB
   - Cache: Write back
   - Discard: Yes (for SSD TRIM)
   - SSD emulation: Yes

6. **CPU Tab:**
   - Sockets: 1
   - Cores: 3
   - Type: host
   - Enable NUMA: No

7. **Memory Tab:**
   - Memory: 12288 MB
   - Minimum memory: 12288 MB
   - Ballooning Device: No (uncheck)

8. **Network Tab:**
   - Bridge: vmbr0
   - Model: VirtIO (paravirtualized)
   - Firewall: No (managed at Talos/K8s level)

9. **Confirm Tab:**
   - Review settings
   - Check "Start after created": No
   - Click "Finish"

### Create VMs via CLI

```bash
# On pve1 - Create control plane VM
qm create 100 \
  --name talos-cp-1 \
  --memory 12288 \
  --balloon 0 \
  --cores 3 \
  --sockets 1 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:100,discard=on,ssd=1 \
  --net0 virtio,bridge=vmbr0 \
  --ide2 nas-iso:iso/talos-amd64.iso,media=cdrom \
  --boot order=ide2

# On pve2 - Create worker VM
qm create 101 \
  --name talos-worker-2 \
  --memory 12288 \
  --balloon 0 \
  --cores 3 \
  --sockets 1 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:100,discard=on,ssd=1 \
  --net0 virtio,bridge=vmbr0 \
  --ide2 nas-iso:iso/talos-amd64.iso,media=cdrom \
  --boot order=ide2

# On pve3 - Create worker VM
qm create 102 \
  --name talos-worker-3 \
  --memory 12288 \
  --balloon 0 \
  --cores 3 \
  --sockets 1 \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:100,discard=on,ssd=1 \
  --net0 virtio,bridge=vmbr0 \
  --ide2 nas-iso:iso/talos-amd64.iso,media=cdrom \
  --boot order=ide2
```

### VM Configuration Summary

| VM ID | Name | Node | Role | IP |
|-------|------|------|------|-----|
| 100 | talos-cp-1 | pve1 | Control Plane + Worker | 192.168.1.21 |
| 101 | talos-worker-2 | pve2 | Worker | 192.168.1.22 |
| 102 | talos-worker-3 | pve3 | Worker | 192.168.1.23 |

### Start VMs and Install Talos

1. Start each VM: `qm start <vmid>`
2. Open console via Web UI
3. Follow Talos installation in [TALOS_KUBERNETES_SETUP.md](./TALOS_KUBERNETES_SETUP.md)

After Talos installation:
1. Remove ISO: Edit VM → Hardware → CD/DVD → Do not use any media
2. Set boot order: Edit VM → Options → Boot Order → scsi0 first
3. Add to HA: Datacenter → HA → Add resource

---

## Backup Configuration

### Configure Scheduled Backups

**Via Web UI:**
1. Datacenter → Backup → Add
2. Configure:
   - Storage: nas-backup
   - Schedule: Daily at 03:00
   - Selection mode: Include selected VMs
   - VMs: Select all Talos VMs
   - Mode: Snapshot
   - Compression: ZSTD
   - Retention: Keep last 7

**Via CLI:**

Edit `/etc/pve/vzdump.cron`:
```
# Daily backup at 3 AM
0 3 * * * root vzdump 100 101 102 --storage nas-backup --mode snapshot --compress zstd --prune-backups keep-last=7
```

### Manual Backup

```bash
# Backup single VM
vzdump 100 --storage nas-backup --mode snapshot --compress zstd

# Backup all Talos VMs
vzdump 100 101 102 --storage nas-backup --mode snapshot --compress zstd
```

### Restore from Backup

**Via Web UI:**
1. Storage → nas-backup → Backups
2. Select backup → Restore
3. Choose target node and storage

**Via CLI:**
```bash
# List backups
ls /mnt/pve/nas-backup/dump/

# Restore VM
qmrestore /mnt/pve/nas-backup/dump/vzdump-qemu-100-*.vma.zst 100 --storage local-lvm
```

---

## Maintenance Operations

### Live Migration

Move running VM to another node without downtime:

**Via Web UI:**
- Right-click VM → Migrate → Select target node → Migrate

**Via CLI:**
```bash
# Migrate VM 100 to pve2
qm migrate 100 pve2 --online
```

### Proxmox Updates

```bash
# On each node
apt update
apt full-upgrade -y

# Reboot if kernel updated
reboot
```

### Node Maintenance Mode

Before performing maintenance on a node:

```bash
# Migrate all VMs off the node
# Via Web UI: Bulk Actions → Migrate

# Or disable node in HA
ha-manager set vm:100 --state disabled
```

### Check Cluster Health

```bash
# Cluster status
pvecm status

# Check quorum
pvecm expected 1  # Temporarily if 2 nodes down (DANGEROUS!)

# Node health
systemctl status pve-cluster pveproxy pvedaemon

# Storage health
pvesm status

# Network connectivity
ping -c 3 192.168.1.12  # From pve1 to pve2
```

---

## Troubleshooting

### Common Issues

#### VM Won't Start

```bash
# Check VM status
qm status 100

# View VM log
qm log 100

# Check storage
pvesm status

# Verify disk exists
lvs | grep vm-100
```

#### Cluster Issues

```bash
# Check corosync
systemctl status corosync
journalctl -u corosync -f

# Check cluster communication
corosync-cfgtool -s

# View cluster log
tail -f /var/log/pve/corosync.log
```

#### HA Not Working

```bash
# Check HA manager
systemctl status pve-ha-lrm pve-ha-crm

# View HA status
ha-manager status

# Check HA logs
journalctl -u pve-ha-lrm -f
```

#### Network Issues

```bash
# Check bridge
brctl show

# Check IP config
ip addr show vmbr0

# Test connectivity
ping 192.168.1.1  # Gateway
ping 192.168.1.5  # NAS
```

#### Storage Issues

```bash
# Check NFS mounts
mount | grep nfs

# Remount NFS
pvesm set nas-backup --disable 0  # Re-enable storage

# Check NAS connectivity
showmount -e 192.168.1.5
```

### Recovery Procedures

#### Single Node Failure

1. HA automatically restarts VMs on remaining nodes
2. Repair or replace failed node
3. Rejoin to cluster: `pvecm add <existing-node-ip>`

#### Loss of Quorum (2 nodes down)

**WARNING: Only use in emergency!**

```bash
# Temporarily set expected votes to 1
pvecm expected 1

# Start critical VMs manually
qm start 100

# Restore other nodes ASAP
```

#### Corrupted Cluster Configuration

```bash
# On affected node, leave cluster
systemctl stop pve-cluster corosync
pmxcfs -l  # Local mode

# Clean cluster config
rm -rf /etc/pve/corosync.conf
rm -rf /etc/corosync/*

# Rejoin cluster
pvecm add <working-node-ip>
```

---

## References

### Official Documentation

- Proxmox VE Documentation: https://pve.proxmox.com/pve-docs/
- Proxmox Wiki: https://pve.proxmox.com/wiki/Main_Page
- Talos Linux: https://www.talos.dev/docs/

### Related Guides

- [TALOS_KUBERNETES_SETUP.md](./TALOS_KUBERNETES_SETUP.md) - Talos installation on VMs
- [K8S_ARCHITECTURE.md](./K8S_ARCHITECTURE.md) - Kubernetes architecture
- [K8S_OPERATIONS.md](./K8S_OPERATIONS.md) - Day-2 operations

### Useful Commands Reference

| Task | Command |
|------|---------|
| Check cluster | `pvecm status` |
| List VMs | `qm list` |
| Start VM | `qm start <vmid>` |
| Stop VM | `qm stop <vmid>` |
| VM console | `qm terminal <vmid>` |
| Migrate VM | `qm migrate <vmid> <node> --online` |
| Backup VM | `vzdump <vmid> --storage <storage>` |
| Restore VM | `qmrestore <backup> <vmid>` |
| Storage status | `pvesm status` |
| HA status | `ha-manager status` |
| Node resources | `pvesh get /nodes/<node>/status` |

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-09 | Added navigation footer |
| 2025-11-27 | Initial documentation for Proxmox virtualization setup |

---

[Back to Main README](../README.md) | [Talos Setup](TALOS_KUBERNETES_SETUP.md) | [Infrastructure as Code](INFRASTRUCTURE_AS_CODE.md) | [K8s Architecture](K8S_ARCHITECTURE.md)
