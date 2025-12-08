# Outputs for Proxmox Terraform Configuration
# These values are used by the Talos Terraform module

output "proxmox_nodes" {
  description = "Available Proxmox nodes"
  value       = data.proxmox_virtual_environment_nodes.available.names
}

output "vm_details" {
  description = "Detailed VM information for each Talos node"
  value = {
    for name, vm in proxmox_virtual_environment_vm.talos : name => {
      vmid        = vm.vm_id
      node        = vm.node_name
      name        = vm.name
      ip_address  = local.talos_vms[name].ip_address
      role        = local.talos_vms[name].role
      cpu_cores   = var.vm_cpu_cores
      memory_mb   = var.vm_memory_mb
      disk_size   = var.vm_disk_size_gb
      status      = vm.started ? "running" : "stopped"
    }
  }
}

output "talos_endpoints" {
  description = "Talos API endpoints for talosctl"
  value = {
    controlplane = ["192.168.1.21"]
    workers      = ["192.168.1.22", "192.168.1.23"]
    all          = ["192.168.1.21", "192.168.1.22", "192.168.1.23"]
  }
}

output "kubernetes_config" {
  description = "Kubernetes cluster configuration"
  value = {
    api_endpoint = "https://${var.kubernetes_api_vip}:6443"
    api_vip      = var.kubernetes_api_vip
    cluster_name = "talos-cluster"
  }
}

output "network_config" {
  description = "Network configuration for Talos"
  value = {
    gateway = var.network_gateway
    dns     = var.network_dns
    subnet  = "192.168.1.0/24"
  }
}

# Output for integration with Talos Terraform module
output "talos_node_config" {
  description = "Configuration to pass to Talos Terraform module"
  value = {
    for name, vm in local.talos_vms : name => {
      ip_address = vm.ip_address
      role       = vm.role
      vmid       = vm.vmid
      node       = vm.node
    }
  }
}
