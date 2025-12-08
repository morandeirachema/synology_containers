# Outputs for Talos Kubernetes Cluster

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "kubernetes_api_endpoint" {
  description = "Kubernetes API endpoint URL"
  value       = "https://${var.kubernetes_api_vip}:6443"
}

output "talosconfig_path" {
  description = "Path to talosconfig file"
  value       = local_sensitive_file.talosconfig.filename
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = local_sensitive_file.kubeconfig.filename
}

output "talos_endpoints" {
  description = "Talos API endpoints"
  value = {
    controlplane = var.controlplane_ips
    workers      = var.worker_ips
    all          = concat(var.controlplane_ips, var.worker_ips)
  }
}

output "cluster_info" {
  description = "Cluster configuration summary"
  value = {
    name               = var.cluster_name
    talos_version      = var.talos_version
    kubernetes_version = var.kubernetes_version
    api_vip            = var.kubernetes_api_vip
    pod_subnet         = var.pod_subnet
    service_subnet     = var.service_subnet
    total_nodes        = length(var.controlplane_ips) + length(var.worker_ips)
    controlplane_count = length(var.controlplane_ips)
    worker_count       = length(var.worker_ips)
  }
}

output "next_steps" {
  description = "Next steps after cluster creation"
  value       = <<-EOT

    Cluster created successfully! Next steps:

    1. Export talosconfig:
       export TALOSCONFIG=${local_sensitive_file.talosconfig.filename}

    2. Export kubeconfig:
       export KUBECONFIG=${local_sensitive_file.kubeconfig.filename}

    3. Verify cluster health:
       talosctl health --nodes ${join(",", concat(var.controlplane_ips, var.worker_ips))}

    4. Check nodes:
       kubectl get nodes

    5. Install Cilium CNI:
       kubectl apply -k ../../../k8s/bootstrap/cilium/

    6. Install MetalLB:
       kubectl apply -k ../../../k8s/bootstrap/metallb/

    7. Deploy full stack:
       kubectl apply -k ../../../k8s/overlays/production/

  EOT
}

# Output machine secrets (sensitive)
output "machine_secrets" {
  description = "Talos machine secrets (sensitive)"
  value       = talos_machine_secrets.this.machine_secrets
  sensitive   = true
}

# Output client configuration (sensitive)
output "client_configuration" {
  description = "Talos client configuration (sensitive)"
  value       = talos_machine_secrets.this.client_configuration
  sensitive   = true
}
