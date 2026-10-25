output "network_name" {
  description = "Name of the VPC."
  value       = google_compute_network.this.name
}

output "network_id" {
  description = "ID of the VPC (projects/<project>/global/networks/<name>)."
  value       = google_compute_network.this.id
}

output "network_self_link" {
  description = "Self link of the VPC. Pass this to the GKE module."
  value       = google_compute_network.this.self_link
}

output "subnet_name" {
  description = "Name of the GKE subnet."
  value       = google_compute_subnetwork.this.name
}

output "subnet_self_link" {
  description = "Self link of the GKE subnet. Pass this to the GKE module."
  value       = google_compute_subnetwork.this.self_link
}

output "subnet_cidr" {
  description = "Primary (node) range of the subnet."
  value       = google_compute_subnetwork.this.ip_cidr_range
}

output "pods_range_name" {
  description = "Name of the secondary range for pods."
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "Name of the secondary range for Services."
  value       = var.services_range_name
}

output "router_name" {
  description = "Name of the Cloud Router."
  value       = google_compute_router.this.name
}

output "nat_name" {
  description = "Name of the Cloud NAT gateway."
  value       = google_compute_router_nat.this.name
}

output "nat_ip_addresses" {
  description = "Static egress IPs reserved for Cloud NAT. Empty when nat_ip_count is 0 (auto-allocated IPs)."
  value       = google_compute_address.nat[*].address
}
