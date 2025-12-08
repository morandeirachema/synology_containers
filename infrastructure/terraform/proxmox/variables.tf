# Variables for Proxmox Terraform Configuration
# Copy terraform.tfvars.example to terraform.tfvars and customize

# =============================================================================
# Proxmox Connection Settings
# =============================================================================

variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://192.168.1.11:8006/api2/json)"
  type        = string
  default     = "https://192.168.1.11:8006/api2/json"
}

variable "proxmox_api_user" {
  description = "Proxmox API user (e.g., root@pam or terraform@pve!terraform)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_api_password" {
  description = "Proxmox API password or token"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate verification"
  type        = bool
  default     = true
}

# =============================================================================
# VM Resource Configuration
# =============================================================================

variable "vm_cpu_cores" {
  description = "Number of CPU cores per VM"
  type        = number
  default     = 3
}

variable "vm_memory_mb" {
  description = "Memory in MB per VM"
  type        = number
  default     = 12288  # 12GB
}

variable "vm_disk_size_gb" {
  description = "Disk size in GB per VM"
  type        = number
  default     = 100
}

variable "vm_storage" {
  description = "Proxmox storage for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "vm_network_bridge" {
  description = "Proxmox network bridge for VMs"
  type        = string
  default     = "vmbr0"
}

# =============================================================================
# Talos Configuration
# =============================================================================

variable "talos_iso_file" {
  description = "Path to Talos ISO in Proxmox storage (e.g., local:iso/talos-amd64.iso)"
  type        = string
  default     = "local:iso/talos-amd64.iso"
}

variable "talos_version" {
  description = "Talos version to use"
  type        = string
  default     = "v1.9.0"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "network_gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.1.1"
}

variable "network_dns" {
  description = "DNS server IPs"
  type        = list(string)
  default     = ["192.168.1.5", "1.1.1.1"]
}

variable "kubernetes_api_vip" {
  description = "Virtual IP for Kubernetes API"
  type        = string
  default     = "192.168.1.20"
}

# =============================================================================
# Deployment Options
# =============================================================================

variable "start_vms_on_create" {
  description = "Start VMs after creation"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
}
