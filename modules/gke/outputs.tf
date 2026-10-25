output "name" {
  description = "Cluster name."
  value       = google_container_cluster.this.name
}

output "id" {
  description = "Cluster ID (projects/<project>/locations/<location>/clusters/<name>)."
  value       = google_container_cluster.this.id
}

output "location" {
  description = "Cluster location (region or zone)."
  value       = google_container_cluster.this.location
}

output "endpoint" {
  description = "Control plane endpoint IP. The private IP when enable_private_endpoint is true."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "ca_certificate" {
  description = "Base64-encoded cluster CA certificate, for configuring the Kubernetes or Helm provider."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "master_version" {
  description = "Current control plane version (moves with the release channel)."
  value       = google_container_cluster.this.master_version
}

output "workload_identity_pool" {
  description = "Workload Identity pool (<project>.svc.id.goog). Read from the cluster, so anything that uses it waits for the cluster, and therefore the pool, to exist."
  value       = google_container_cluster.this.workload_identity_config[0].workload_pool
}

output "node_service_account_email" {
  description = "Email of the node service account."
  value       = google_service_account.nodes.email
}

output "node_pools" {
  description = "Node pools by name, with the settings that matter when scheduling workloads."
  value = {
    for name, pool in google_container_node_pool.this : name => {
      machine_type = pool.node_config[0].machine_type
      spot         = pool.node_config[0].spot
      min_count    = pool.autoscaling[0].min_node_count
      max_count    = pool.autoscaling[0].max_node_count
      taints       = var.node_pools[name].taints
    }
  }
}
