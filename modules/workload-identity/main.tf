locals {
  workload_identity_pool = coalesce(var.workload_identity_pool, "${var.project_id}.svc.id.goog")

  # The Kubernetes service account, as an IAM principal.
  kubernetes_member = "serviceAccount:${local.workload_identity_pool}[${var.namespace}/${var.kubernetes_service_account}]"
}

# The API caps display names at 100 characters and descriptions at 256, hence
# the substr() calls on the generated defaults.
resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = substr(coalesce(var.display_name, "Workload Identity: ${var.namespace}/${var.kubernetes_service_account}"), 0, 100)
  description  = substr(coalesce(var.description, "Impersonated by Kubernetes service account ${var.namespace}/${var.kubernetes_service_account} via Workload Identity. Managed by Terraform."), 0, 256)
}

resource "google_project_iam_member" "this" {
  for_each = toset(var.project_roles)

  project = var.project_id
  role    = each.value
  member  = google_service_account.this.member
}

# Lets the Kubernetes service account obtain short-lived tokens for the GCP
# service account. Fails if the pool does not exist yet, i.e. before the first
# Workload Identity-enabled cluster in the pool's project has been created.
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.this.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.kubernetes_member
}
