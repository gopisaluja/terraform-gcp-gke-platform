output "email" {
  description = "Email of the GCP service account."
  value       = google_service_account.this.email
}

output "name" {
  description = "Fully qualified name of the GCP service account (projects/<p>/serviceAccounts/<email>)."
  value       = google_service_account.this.name
}

output "member" {
  description = "IAM member string for the GCP service account (serviceAccount:<email>), for resource-level grants."
  value       = google_service_account.this.member
}

output "kubernetes_member" {
  description = "IAM principal of the Kubernetes service account that is allowed to impersonate the GCP service account."
  value       = local.kubernetes_member
}

output "kubernetes_annotation" {
  description = "Annotation to put on the Kubernetes service account so GKE maps it to the GCP service account."
  value = {
    "iam.gke.io/gcp-service-account" = google_service_account.this.email
  }
}
