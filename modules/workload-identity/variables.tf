variable "project_id" {
  description = "ID of the GCP project for the service account and its project-level role bindings."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (6-30 chars, lowercase letters, digits and hyphens)."
  }
}

variable "account_id" {
  description = "Account ID of the GCP service account to create (the part before @)."
  type        = string

  validation {
    condition     = can(regex("^[a-z](?:[-a-z0-9]{4,28}[a-z0-9])$", var.account_id))
    error_message = "account_id must be 6-30 chars, start with a letter, end with a letter or digit, and contain only lowercase letters, digits and hyphens."
  }
}

variable "display_name" {
  description = "Display name of the service account. null generates one from the namespace and Kubernetes service account."
  type        = string
  default     = null
}

variable "description" {
  description = "Description of the service account. null generates one."
  type        = string
  default     = null
}

variable "namespace" {
  description = "Kubernetes namespace of the service account that will impersonate the GCP service account."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", var.namespace))
    error_message = "namespace must be a valid Kubernetes namespace name (RFC 1123 label, max 63 chars)."
  }
}

variable "kubernetes_service_account" {
  description = "Name of the Kubernetes service account (in namespace) that will impersonate the GCP service account."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9.]{0,251}[a-z0-9])?$", var.kubernetes_service_account))
    error_message = "kubernetes_service_account must be a valid Kubernetes object name (RFC 1123 subdomain)."
  }
}

variable "project_roles" {
  description = "Roles to grant the service account on project_id, e.g. [\"roles/cloudsql.client\"]. Prefer resource-level grants (a bucket, a secret, a topic) using the member output when the resource is known."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for r in var.project_roles :
      can(regex("^(roles/[a-zA-Z0-9_.]+|projects/[^/]+/roles/[a-zA-Z0-9_.]+|organizations/[0-9]+/roles/[a-zA-Z0-9_.]+)$", r))
    ])
    error_message = "Each role must look like roles/<name>, projects/<p>/roles/<name> or organizations/<id>/roles/<name>."
  }

  validation {
    condition     = length(setintersection(var.project_roles, ["roles/owner", "roles/editor"])) == 0
    error_message = "Do not grant basic roles (roles/owner, roles/editor) to a workload. Pick predefined or custom roles."
  }
}

variable "workload_identity_pool" {
  description = "Workload Identity pool of the cluster, normally the GKE module's workload_identity_pool output (which also orders this after the cluster). null uses <project_id>.svc.id.goog."
  type        = string
  default     = null

  validation {
    condition     = var.workload_identity_pool == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]\\.svc\\.id\\.goog$", var.workload_identity_pool))
    error_message = "workload_identity_pool must look like <project-id>.svc.id.goog."
  }
}
