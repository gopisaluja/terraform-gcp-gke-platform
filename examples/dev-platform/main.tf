locals {
  # Every resource is named <name>-<environment>-<thing>, e.g. platform-dev-vpc.
  name_prefix = "${var.name}-${var.environment}"

  # One label map for everything that supports labels. The modules add
  # managed-by=terraform themselves as well; it is listed here so the
  # convention is visible in one place.
  labels = {
    env         = var.environment
    team        = var.team
    cost-center = var.cost_center
    managed-by  = "terraform"
  }

  # Shared between the network module (IAP SSH firewall target) and the GKE
  # module (tag on every node).
  node_network_tag = "${local.name_prefix}-gke-node"

  required_apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

resource "google_project_service" "this" {
  for_each = var.enable_project_apis ? toset(local.required_apis) : toset([])

  project = var.project_id
  service = each.value

  # Leave APIs on when this stack is destroyed; other things in the project
  # may depend on them.
  disable_on_destroy = false
}

module "network" {
  source = "../../modules/network"

  project_id    = var.project_id
  name          = local.name_prefix
  region        = var.region
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr

  nat_ip_count        = var.nat_ip_count
  enable_iap_ssh      = var.enable_iap_ssh
  iap_ssh_target_tags = [local.node_network_tag]

  labels = local.labels

  depends_on = [google_project_service.this]
}

module "gke" {
  source = "../../modules/gke"

  project_id = var.project_id
  name       = "${local.name_prefix}-gke"
  location   = var.region

  network             = module.network.network_self_link
  subnetwork          = module.network.subnet_self_link
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  master_ipv4_cidr_block     = var.master_ipv4_cidr_block
  master_authorized_networks = var.master_authorized_networks

  release_channel     = var.release_channel
  autoscaling_profile = "OPTIMIZE_UTILIZATION"
  logging_components  = var.logging_components

  node_network_tags = [local.node_network_tag]
  node_pools        = var.node_pools

  deletion_protection = var.deletion_protection
  labels              = local.labels

  depends_on = [google_project_service.this]
}

module "workload_identity" {
  source   = "../../modules/workload-identity"
  for_each = var.workload_identities

  project_id                 = var.project_id
  account_id                 = "${local.name_prefix}-${each.key}"
  namespace                  = each.value.namespace
  kubernetes_service_account = each.value.kubernetes_service_account
  project_roles              = each.value.project_roles

  # Taken from the cluster so the IAM binding waits for the pool to exist.
  workload_identity_pool = module.gke.workload_identity_pool

  depends_on = [google_project_service.this]
}
