locals {
  node_service_account_id = coalesce(var.node_service_account_id, "${var.name}-nodes")
}

# Dedicated identity for nodes. The Compute Engine default service account is
# often granted Editor on the project, which every pod could otherwise inherit
# through the metadata server.
resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = local.node_service_account_id
  display_name = "GKE nodes: ${var.name}"
  description  = "Least-privilege identity for nodes in GKE cluster ${var.name}. Managed by Terraform."

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z](?:[-a-z0-9]{4,28}[a-z0-9])$", local.node_service_account_id))
      error_message = "Derived node service account ID \"${local.node_service_account_id}\" is not valid (6-30 chars, lowercase letters, digits, hyphens). Set node_service_account_id explicitly."
    }
  }
}

resource "google_project_iam_member" "nodes" {
  for_each = toset(var.node_service_account_roles)

  project = var.project_id
  role    = each.value
  member  = google_service_account.nodes.member
}
