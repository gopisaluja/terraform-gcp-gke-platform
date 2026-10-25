# GKE creates and maintains its own firewall rules for the cluster (control plane
# to kubelet, intra-cluster traffic, load balancer health checks). The rules here
# cover only what GKE does not: a logged baseline deny and IAP-based SSH.

# Explicit copy of the implied "deny all ingress" rule. The implied rule cannot be
# logged; this one can, so dropped connection attempts show up in Cloud Logging.
# Anything with a higher priority (lower number), including GKE's rules, wins.
resource "google_compute_firewall" "deny_all_ingress" {
  count = var.log_denied_ingress ? 1 : 0

  project     = var.project_id
  name        = "${var.name}-deny-all-ingress"
  description = "Baseline deny for all ingress, logged. Managed by Terraform."
  network     = google_compute_network.this.id
  direction   = "INGRESS"
  priority    = 65534

  source_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# SSH to nodes only through Identity-Aware Proxy TCP forwarding. IAP still checks
# IAM (roles/iap.tunnelResourceAccessor) before a tunnel is opened.
resource "google_compute_firewall" "allow_iap_ssh" {
  count = var.enable_iap_ssh ? 1 : 0

  project     = var.project_id
  name        = "${var.name}-allow-iap-ssh"
  description = "SSH from the IAP TCP forwarding range to tagged instances. Managed by Terraform."
  network     = google_compute_network.this.id
  direction   = "INGRESS"
  priority    = 1000

  source_ranges = ["35.235.240.0/20"]
  target_tags   = var.iap_ssh_target_tags

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  lifecycle {
    precondition {
      condition     = length(var.iap_ssh_target_tags) > 0
      error_message = "enable_iap_ssh is true but iap_ssh_target_tags is empty. Set at least one target tag so the rule does not apply to every instance in the VPC."
    }
  }
}
