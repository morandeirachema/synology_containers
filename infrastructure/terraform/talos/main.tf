# Talos Kubernetes Cluster Configuration
# This Terraform configuration manages Talos Linux cluster setup
#
# Prerequisites:
# - Proxmox VMs created (via ../proxmox/)
# - VMs booted with Talos ISO
# - Network connectivity to VMs

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Remote backend for state management
  # backend "s3" {
  #   bucket   = "terraform-state"
  #   key      = "talos/terraform.tfstate"
  #   region   = "us-east-1"
  #   endpoint = "http://192.168.1.5:9000"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   force_path_style            = true
  # }
}

# =============================================================================
# Talos Machine Secrets
# =============================================================================

# Generate machine secrets for the cluster
resource "talos_machine_secrets" "this" {}

# =============================================================================
# Talos Client Configuration
# =============================================================================

# Generate talosconfig for CLI access
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = var.controlplane_ips
  nodes                = concat(var.controlplane_ips, var.worker_ips)
}

# =============================================================================
# Control Plane Configuration
# =============================================================================

# Generate control plane machine configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.kubernetes_api_vip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/vda"
          image = "ghcr.io/siderolabs/installer:${var.talos_version}"
          wipe  = false
        }
        network = {
          hostname = "talos-cp-1"
          interfaces = [{
            interface = "eth0"
            dhcp      = false
            addresses = ["${var.controlplane_ips[0]}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
            vip = {
              ip = var.kubernetes_api_vip
            }
          }]
          nameservers = var.network_dns
        }
        kubelet = {
          extraArgs = {
            "rotate-server-certificates" = "true"
          }
          nodeIP = {
            validSubnets = [var.network_subnet]
          }
        }
        # Allow scheduling on control plane (hybrid node)
        nodeLabels = {
          "node-role.kubernetes.io/worker" = ""
        }
      }
      cluster = {
        allowSchedulingOnControlPlanes = true
        network = {
          cni = {
            name = "none"  # We'll install Cilium separately
          }
          podSubnets     = [var.pod_subnet]
          serviceSubnets = [var.service_subnet]
        }
        proxy = {
          disabled = true  # Cilium handles kube-proxy
        }
      }
    })
  ]
}

# =============================================================================
# Worker Configuration
# =============================================================================

# Generate worker machine configuration for each worker
data "talos_machine_configuration" "worker" {
  for_each = { for idx, ip in var.worker_ips : "worker-${idx + 2}" => ip }

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.kubernetes_api_vip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/vda"
          image = "ghcr.io/siderolabs/installer:${var.talos_version}"
          wipe  = false
        }
        network = {
          hostname = "talos-${each.key}"
          interfaces = [{
            interface = "eth0"
            dhcp      = false
            addresses = ["${each.value}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
          }]
          nameservers = var.network_dns
        }
        kubelet = {
          extraArgs = {
            "rotate-server-certificates" = "true"
          }
          nodeIP = {
            validSubnets = [var.network_subnet]
          }
        }
      }
    })
  ]
}

# =============================================================================
# Apply Configurations
# =============================================================================

# Apply configuration to control plane
resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.controlplane_ips[0]

  config_patches = [
    yamlencode({
      machine = {
        certSANs = [
          var.kubernetes_api_vip,
          var.controlplane_ips[0],
          "talos-cp-1",
          "localhost",
          "127.0.0.1"
        ]
      }
    })
  ]
}

# Apply configuration to workers
resource "talos_machine_configuration_apply" "worker" {
  for_each = { for idx, ip in var.worker_ips : "worker-${idx + 2}" => ip }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  node                        = each.value

  depends_on = [talos_machine_configuration_apply.controlplane]
}

# =============================================================================
# Bootstrap Cluster
# =============================================================================

# Bootstrap the Kubernetes cluster
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips[0]

  depends_on = [talos_machine_configuration_apply.controlplane]
}

# =============================================================================
# Kubeconfig
# =============================================================================

# Get kubeconfig for kubectl access
data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips[0]

  depends_on = [talos_machine_bootstrap.this]
}

# =============================================================================
# Output Files
# =============================================================================

# Save talosconfig to file
resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/outputs/talosconfig"
  file_permission = "0600"
}

# Save kubeconfig to file
resource "local_sensitive_file" "kubeconfig" {
  content         = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.module}/outputs/kubeconfig"
  file_permission = "0600"

  depends_on = [talos_machine_bootstrap.this]
}

# Save control plane config for reference
resource "local_file" "controlplane_config" {
  content  = data.talos_machine_configuration.controlplane.machine_configuration
  filename = "${path.module}/outputs/controlplane.yaml"

  # Ensure directory exists
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/outputs"
  }
}
