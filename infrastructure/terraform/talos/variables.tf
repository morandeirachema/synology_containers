# Variables for Talos Kubernetes Cluster Configuration

# =============================================================================
# Cluster Configuration
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "talos-cluster"
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.9.0"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31.0"
}

# =============================================================================
# Node IP Addresses
# =============================================================================

variable "controlplane_ips" {
  description = "IP addresses of control plane nodes"
  type        = list(string)
  default     = ["192.168.1.21"]
}

variable "worker_ips" {
  description = "IP addresses of worker nodes"
  type        = list(string)
  default     = ["192.168.1.22", "192.168.1.23"]
}

variable "kubernetes_api_vip" {
  description = "Virtual IP for Kubernetes API server"
  type        = string
  default     = "192.168.1.20"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "network_gateway" {
  description = "Network gateway IP address"
  type        = string
  default     = "192.168.1.1"
}

variable "network_dns" {
  description = "DNS server IP addresses"
  type        = list(string)
  default     = ["192.168.1.5", "1.1.1.1"]
}

variable "network_subnet" {
  description = "Network subnet for node IPs"
  type        = string
  default     = "192.168.1.0/24"
}

variable "pod_subnet" {
  description = "Pod network CIDR"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_subnet" {
  description = "Service network CIDR"
  type        = string
  default     = "10.96.0.0/12"
}

# =============================================================================
# Cluster Features
# =============================================================================

variable "allow_scheduling_on_controlplane" {
  description = "Allow scheduling workloads on control plane nodes"
  type        = bool
  default     = true
}

variable "install_cni" {
  description = "Install CNI plugin (set to false if using Cilium)"
  type        = bool
  default     = false
}

variable "disable_kube_proxy" {
  description = "Disable kube-proxy (set to true if using Cilium)"
  type        = bool
  default     = true
}
