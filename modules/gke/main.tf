locals {
  # managed-by is always set, whatever the caller passes.
  labels = merge(var.labels, { managed-by = "terraform" })

  workload_identity_pool = "${var.project_id}.svc.id.goog"
}

resource "google_container_cluster" "this" {
  project     = var.project_id
  name        = var.name
  description = "Managed by Terraform."

  # A region gives a regional cluster (replicated control plane, nodes in every
  # zone listed in node_locations, or in three zones by default). A zone gives a
  # zonal cluster.
  location       = var.location
  node_locations = length(var.node_locations) > 0 ? var.node_locations : null

  deletion_protection = var.deletion_protection

  # Node pools are managed in node_pools.tf. GKE still creates a default pool
  # when the cluster is created; it is built with the dedicated node service
  # account (not the Compute Engine default one) and deleted straight away.
  remove_default_node_pool = true
  initial_node_count       = 1

  node_config {
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  network                   = var.network
  subnetwork                = var.subnetwork
  networking_mode           = "VPC_NATIVE"
  default_max_pods_per_node = var.max_pods_per_node

  # Dataplane V2 (eBPF). NetworkPolicy is enforced natively, so neither the
  # network_policy block nor the Calico add-on is set. Cannot be changed later
  # without recreating the cluster.
  datapath_provider = "ADVANCED_DATAPATH"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

    master_global_access_config {
      enabled = var.enable_master_global_access
    }
  }

  # Always on. An empty list means no external CIDR can reach the public
  # endpoint; the node subnet can always reach the private endpoint.
  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled = false

    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks

      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  workload_identity_config {
    workload_pool = local.workload_identity_pool
  }

  release_channel {
    channel = var.release_channel
  }

  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_window.start_time
      end_time   = var.maintenance_window.end_time
      recurrence = var.maintenance_window.recurrence
    }

    dynamic "maintenance_exclusion" {
      for_each = var.maintenance_exclusions

      content {
        exclusion_name = maintenance_exclusion.value.name
        start_time     = maintenance_exclusion.value.start_time
        end_time       = maintenance_exclusion.value.end_time

        exclusion_options {
          scope = maintenance_exclusion.value.scope
        }
      }
    }
  }

  enable_shielded_nodes = true
  enable_legacy_abac    = false

  logging_config {
    enable_components = var.logging_components
  }

  monitoring_config {
    enable_components = var.monitoring_components

    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = false
    }

    gce_persistent_disk_csi_driver_config {
      enabled = true
    }

    dns_cache_config {
      enabled = var.enable_node_local_dns_cache
    }
  }

  vertical_pod_autoscaling {
    enabled = var.enable_vertical_pod_autoscaling
  }

  cluster_autoscaling {
    autoscaling_profile = var.autoscaling_profile
  }

  # GKE cost allocation: breaks cluster cost down by namespace and k8s label in
  # the Cloud Billing export. No extra charge.
  cost_management_config {
    enabled = var.enable_cost_allocation
  }

  # Application-layer encryption of Kubernetes Secrets in etcd with a Cloud KMS
  # key, when one is supplied.
  database_encryption {
    state    = var.database_encryption_key_name == null ? "DECRYPTED" : "ENCRYPTED"
    key_name = var.database_encryption_key_name
  }

  resource_labels = local.labels

  lifecycle {
    # node_config and initial_node_count only describe the throwaway default
    # pool. Changing either would otherwise force a cluster replacement.
    ignore_changes = [node_config, initial_node_count]
  }

  depends_on = [google_project_iam_member.nodes]
}

# Admission webhooks run on nodes, and the control plane has to reach them. GKE
# only opens 443 and 10250 from the control plane range, so webhooks on other
# ports (ingress-nginx, Gatekeeper, Istio, many operators) time out without this.
resource "google_compute_firewall" "control_plane_webhooks" {
  count = length(var.master_webhook_ports) > 0 ? 1 : 0

  project     = var.project_id
  name        = "${var.name}-allow-cp-webhooks"
  description = "Control plane to node admission webhooks for ${var.name}. Managed by Terraform."
  network     = var.network
  direction   = "INGRESS"
  priority    = 1000

  source_ranges           = [var.master_ipv4_cidr_block]
  target_service_accounts = [google_service_account.nodes.email]

  allow {
    protocol = "tcp"
    ports    = var.master_webhook_ports
  }
}
