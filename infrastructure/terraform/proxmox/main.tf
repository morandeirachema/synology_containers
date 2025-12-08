# Proxmox VM Infrastructure for Talos Kubernetes Cluster
# This Terraform configuration creates VMs on Proxmox for running Talos Linux
#
# Prerequisites:
# - Proxmox VE 9.x installed on all nodes
# - API token created in Proxmox
# - Talos ISO uploaded to Proxmox storage

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70"
    }
  }

  # Remote backend for state management (recommended for GitOps)
  # Uncomment and configure for production use
  # backend "s3" {
  #   bucket         = "terraform-state"
  #   key            = "proxmox/terraform.tfstate"
  #   region         = "us-east-1"
  #   endpoint       = "http://192.168.1.5:9000"  # MinIO on Synology
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   force_path_style            = true
  # }
}

# Configure the Proxmox provider
provider "proxmox" {
  endpoint = var.proxmox_api_url
  username = var.proxmox_api_user
  password = var.proxmox_api_password

  # Skip TLS verification for self-signed certificates
  insecure = var.proxmox_insecure

  ssh {
    agent = true
  }
}

# Data source to get Proxmox nodes
data "proxmox_virtual_environment_nodes" "available" {}

# Local values for VM configuration
locals {
  # Map of Talos VMs to create
  talos_vms = {
    "talos-cp-1" = {
      vmid        = 100
      node        = "pve1"
      ip_address  = "192.168.1.21"
      role        = "controlplane"
      description = "Talos Control Plane + Worker"
    }
    "talos-worker-2" = {
      vmid        = 101
      node        = "pve2"
      ip_address  = "192.168.1.22"
      role        = "worker"
      description = "Talos Worker Node 2"
    }
    "talos-worker-3" = {
      vmid        = 102
      node        = "pve3"
      ip_address  = "192.168.1.23"
      role        = "worker"
      description = "Talos Worker Node 3"
    }
  }

  # Common tags for all resources
  common_tags = [
    "terraform",
    "talos",
    "kubernetes"
  ]
}

# Create Talos VMs
resource "proxmox_virtual_environment_vm" "talos" {
  for_each = local.talos_vms

  name        = each.key
  description = each.value.description
  tags        = local.common_tags

  node_name = each.value.node
  vm_id     = each.value.vmid

  # Machine type and BIOS
  machine = "q35"
  bios    = "ovmf"

  # CPU Configuration
  cpu {
    cores   = var.vm_cpu_cores
    sockets = 1
    type    = "host"
  }

  # Memory Configuration (no ballooning for Kubernetes)
  memory {
    dedicated = var.vm_memory_mb
    floating  = 0
  }

  # EFI Disk for UEFI boot
  efi_disk {
    datastore_id = var.vm_storage
    type         = "4m"
  }

  # Boot disk
  disk {
    datastore_id = var.vm_storage
    size         = var.vm_disk_size_gb
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
    file_format  = "raw"
  }

  # CD-ROM with Talos ISO
  cdrom {
    enabled   = true
    file_id   = var.talos_iso_file
    interface = "ide2"
  }

  # Network adapter
  network_device {
    bridge = var.vm_network_bridge
    model  = "virtio"
  }

  # SCSI controller
  scsi_hardware = "virtio-scsi-single"

  # Boot order
  boot_order = ["ide2", "scsi0"]

  # Agent disabled (Talos doesn't support qemu-agent)
  agent {
    enabled = false
  }

  # Operating system type
  operating_system {
    type = "l26"
  }

  # Start VM after creation
  started = var.start_vms_on_create

  # Lifecycle settings
  lifecycle {
    ignore_changes = [
      cdrom,  # Allow manual ISO removal after install
      boot_order,
    ]
  }
}

# Output VM information
output "talos_vms" {
  description = "Created Talos VM information"
  value = {
    for name, vm in proxmox_virtual_environment_vm.talos : name => {
      vmid       = vm.vm_id
      node       = vm.node_name
      ip_address = local.talos_vms[name].ip_address
      role       = local.talos_vms[name].role
    }
  }
}

output "controlplane_ip" {
  description = "Control plane IP address"
  value       = "192.168.1.21"
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value       = ["192.168.1.22", "192.168.1.23"]
}

output "kubernetes_api_vip" {
  description = "Kubernetes API VIP (for kubeconfig)"
  value       = var.kubernetes_api_vip
}
