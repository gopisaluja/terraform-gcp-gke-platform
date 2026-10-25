output "cluster_name" {
  description = "Name of the GKE cluster."
  value       = module.gke.name
}

output "cluster_location" {
  description = "Location (region) of the GKE cluster."
  value       = module.gke.location
}

output "get_credentials_command" {
  description = "Command that writes a kubeconfig entry for the cluster. Your IP must be in master_authorized_networks."
  value       = "gcloud container clusters get-credentials ${module.gke.name} --location ${module.gke.location} --project ${var.project_id}"
}

output "network_name" {
  description = "Name of the VPC."
  value       = module.network.network_name
}

output "subnet_name" {
  description = "Name of the GKE subnet."
  value       = module.network.subnet_name
}

output "nat_ip_addresses" {
  description = "Static Cloud NAT egress IPs (empty when auto-allocated)."
  value       = module.network.nat_ip_addresses
}

output "node_service_account_email" {
  description = "Service account used by the GKE nodes."
  value       = module.gke.node_service_account_email
}

output "node_pools" {
  description = "Node pools with machine type, Spot flag, autoscaling bounds and taints."
  value       = module.gke.node_pools
}

output "workload_identities" {
  description = "Per workload: the GCP service account email and the annotation to put on the Kubernetes service account."
  value = {
    for key, wi in module.workload_identity : key => {
      email      = wi.email
      annotation = wi.kubernetes_annotation
    }
  }
}
