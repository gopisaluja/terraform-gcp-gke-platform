variable "project_id" {
  description = "ID of an existing GCP project to deploy into (placeholder: \"my-dev-project\"). Billing must be enabled."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (6-30 chars, lowercase letters, digits and hyphens)."
  }
}

variable "region" {
  description = "Region for the network and the regional cluster."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "Platform name, the first part of every resource name (<name>-<environment>-...)."
  type        = string
  default     = "platform"

  # Max 11 so the longest derived ID, <name>-<environment>-gke-nodes, stays
  # within the 30-character service account limit.
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,10}$", var.name))
    error_message = "name must be 2-11 lowercase letters or digits, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name. Used in resource names and as the env label."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.environment))
    error_message = "environment must be 2-8 lowercase letters or digits, starting with a letter (dev, stg, prod, ...)."
  }
}

variable "team" {
  description = "Owning team, applied as the team label."
  type        = string
  default     = "platform"
}

variable "cost_center" {
  description = "Cost center, applied as the cost-center label so spend can be grouped in the billing export."
  type        = string
  default     = "unassigned"
}

variable "enable_project_apis" {
  description = "Enable the GCP APIs this stack needs. Turn off if APIs are managed elsewhere (for example by a project factory)."
  type        = bool
  default     = true
}

variable "subnet_cidr" {
  description = "Node range of the GKE subnet."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Pod secondary range."
  type        = string
  default     = "10.16.0.0/14"
}

variable "services_cidr" {
  description = "Service secondary range."
  type        = string
  default     = "10.20.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = "/28 for the GKE control plane. Must not overlap the ranges above or anything peered with the VPC."
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "CIDRs allowed to reach the cluster's public endpoint, typically your office or VPN egress. With the default (empty) kubectl only works from inside the VPC."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "nat_ip_count" {
  description = "Static egress IPs for Cloud NAT. 0 uses auto-allocated IPs."
  type        = number
  default     = 0
}

variable "enable_iap_ssh" {
  description = "Allow SSH to nodes through IAP (for debugging). Access still requires roles/iap.tunnelResourceAccessor."
  type        = bool
  default     = true
}

variable "release_channel" {
  description = "GKE release channel. REGULAR suits dev; consider STABLE for production so dev sees new versions first."
  type        = string
  default     = "REGULAR"
}

variable "logging_components" {
  description = "Cluster components that log to Cloud Logging. Use [\"SYSTEM_COMPONENTS\"] if container logs go to an in-cluster stack instead."
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

# Typed as `any` on purpose: the gke module declares the full object type with
# optional attributes and validates it, so repeating that schema here would only
# give it a chance to drift.
variable "node_pools" {
  description = "Node pools, passed straight to the gke module (see modules/gke/variables.tf for the schema). Counts are per zone."
  type        = any
  default = {
    general = {
      machine_type = "e2-standard-4"
      min_count    = 1
      max_count    = 3
    }

    spot-batch = {
      machine_type = "n2d-standard-4"
      spot         = true
      min_count    = 0
      max_count    = 5
      labels = {
        workload-type = "batch"
      }
      taints = [
        {
          key    = "cloud.google.com/gke-spot"
          value  = "true"
          effect = "NO_SCHEDULE"
        },
      ]
    }
  }
}

variable "workload_identities" {
  description = "GCP service accounts to create for Kubernetes workloads, keyed by a short name that becomes part of the account ID (<name>-<environment>-<key>, max 30 chars)."
  type = map(object({
    namespace                  = string
    kubernetes_service_account = string
    project_roles              = optional(list(string), [])
  }))
  default = {}
}

variable "deletion_protection" {
  description = "Protect the cluster from terraform destroy. Set to false and apply before tearing the example down."
  type        = bool
  default     = true
}
