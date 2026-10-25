resource "google_container_node_pool" "this" {
  for_each = var.node_pools

  project  = var.project_id
  name     = each.key
  cluster  = google_container_cluster.this.id
  location = google_container_cluster.this.location

  # Per zone, like min/max below. Ignored after creation so autoscaling and
  # manual resizes do not force a pool replacement.
  initial_node_count = each.value.min_count

  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count

    # Spot capacity varies by zone; ANY lets the autoscaler use whichever zone
    # has it. On-demand pools stay balanced across zones.
    location_policy = each.value.spot ? "ANY" : "BALANCED"
  }

  # Release channels require auto-upgrade; auto-repair replaces unhealthy nodes.
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = each.value.max_surge
    max_unavailable = each.value.max_unavailable
  }

  node_config {
    machine_type = each.value.machine_type
    image_type   = each.value.image_type
    disk_type    = each.value.disk_type
    disk_size_gb = each.value.disk_size_gb
    spot         = each.value.spot

    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Kubernetes node labels.
    labels = each.value.labels

    # GCE labels on the VMs and disks, which is what shows up in billing.
    resource_labels = merge(local.labels, { node-pool = each.key })

    tags = distinct(concat(var.node_network_tags, each.value.network_tags))

    metadata = {
      disable-legacy-endpoints = "true"
    }

    dynamic "taint" {
      for_each = each.value.taints

      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    # Pods see the GKE metadata server, not the node's credentials.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }

  depends_on = [google_project_iam_member.nodes]
}

# Warns (does not fail) when a Spot pool has no taints, because untolerated
# workloads would then land on capacity that can be reclaimed at any time.
check "spot_pools_are_tainted" {
  assert {
    condition     = alltrue([for name, pool in var.node_pools : !pool.spot || length(pool.taints) > 0])
    error_message = "Spot node pool(s) without taints: ${join(", ", [for name, pool in var.node_pools : name if pool.spot && length(pool.taints) == 0])}. Add a NO_SCHEDULE taint so only workloads that tolerate preemption are scheduled there."
  }
}
