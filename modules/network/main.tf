locals {
  # managed-by is always set, whatever the caller passes.
  labels = merge(var.labels, { managed-by = "terraform" })

  # Plan-time overlap check for the three subnet ranges. The API would reject an
  # overlap too, but only halfway through an apply.
  cidrs = {
    subnet   = var.subnet_cidr
    pods     = var.pods_cidr
    services = var.services_cidr
  }
  cidr_names = keys(local.cidrs)

  # First and last address of each range as an integer.
  cidr_bounds = {
    for name, cidr in local.cidrs : name => [
      for addr in [cidrhost(cidr, 0), cidrhost(cidr, -1)] :
      sum([for i, octet in split(".", addr) : tonumber(octet) * pow(256, 3 - i)])
    ]
  }

  overlapping_cidrs = flatten([
    for i, a in local.cidr_names : [
      for j, b in local.cidr_names : "${a} (${local.cidrs[a]}) / ${b} (${local.cidrs[b]})"
      if i < j && local.cidr_bounds[a][0] <= local.cidr_bounds[b][1] && local.cidr_bounds[b][0] <= local.cidr_bounds[a][1]
    ]
  ])
}

resource "google_compute_network" "this" {
  project     = var.project_id
  name        = "${var.name}-vpc"
  description = "VPC for ${var.name}. Managed by Terraform."

  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  # Keep the default internet route: Cloud NAT needs it for egress. Nodes have no
  # external IPs, so the route alone does not expose anything.
  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "this" {
  project     = var.project_id
  name        = "${var.name}-gke-${var.region}"
  description = "GKE nodes (primary range), pods and services (secondary ranges). Managed by Terraform."
  region      = var.region
  network     = google_compute_network.this.id
  stack_type  = "IPV4_ONLY"

  ip_cidr_range = var.subnet_cidr

  # Lets nodes without external IPs reach Google APIs (Artifact Registry, GCS,
  # Cloud Logging, ...) without going through Cloud NAT.
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = var.pods_range_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = var.services_range_name
    ip_cidr_range = var.services_cidr
  }

  dynamic "log_config" {
    for_each = var.flow_logs.enabled ? [var.flow_logs] : []

    content {
      aggregation_interval = log_config.value.aggregation_interval
      flow_sampling        = log_config.value.sampling
      metadata             = log_config.value.metadata
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.overlapping_cidrs) == 0
      error_message = "Subnet, pod and service ranges must not overlap. Overlapping: ${join(", ", local.overlapping_cidrs)}."
    }
  }
}

resource "google_compute_router" "this" {
  project = var.project_id
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.this.id
}

# Optional static egress IPs, for when a third party needs to allowlist you.
resource "google_compute_address" "nat" {
  count = var.nat_ip_count

  project      = var.project_id
  name         = "${var.name}-nat-${count.index}"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  labels       = local.labels
}

resource "google_compute_router_nat" "this" {
  project = var.project_id
  name    = "${var.name}-nat"
  region  = var.region
  router  = google_compute_router.this.name

  nat_ip_allocate_option = var.nat_ip_count > 0 ? "MANUAL_ONLY" : "AUTO_ONLY"
  nat_ips                = var.nat_ip_count > 0 ? google_compute_address.nat[*].self_link : null

  # Only this subnet gets NAT. ALL_IP_RANGES covers the pod range as well as nodes.
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.this.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  # Dynamic port allocation gives busy nodes more ports without reserving the
  # maximum for every VM. It cannot be combined with endpoint-independent mapping.
  enable_dynamic_port_allocation      = true
  enable_endpoint_independent_mapping = false
  min_ports_per_vm                    = var.nat_min_ports_per_vm
  max_ports_per_vm                    = var.nat_max_ports_per_vm

  log_config {
    enable = true
    filter = var.nat_log_filter
  }

  lifecycle {
    precondition {
      condition     = var.nat_max_ports_per_vm > var.nat_min_ports_per_vm
      error_message = "nat_max_ports_per_vm must be larger than nat_min_ports_per_vm."
    }
  }
}
