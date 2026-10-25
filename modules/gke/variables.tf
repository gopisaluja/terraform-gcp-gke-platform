variable "project_id" {
  description = "ID of the GCP project to create the cluster in."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (6-30 chars, lowercase letters, digits and hyphens)."
  }
}

variable "name" {
  description = "Cluster name. Also used as the prefix for the node service account and the webhook firewall rule."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$", var.name))
    error_message = "name must be 1-40 chars, start with a letter, and contain only lowercase letters, digits and hyphens."
  }
}

variable "location" {
  description = "Region (regional cluster, recommended) or zone (zonal cluster) for the control plane, e.g. \"us-central1\" or \"us-central1-a\"."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+(-[a-z])?$", var.location))
    error_message = "location must be a region such as \"us-central1\" or a zone such as \"us-central1-a\"."
  }
}

variable "node_locations" {
  description = "Zones to run nodes in. Empty uses GKE's default (three zones for a regional cluster, the cluster zone for a zonal one). Node counts in node_pools are per zone."
  type        = list(string)
  default     = []
}

variable "network" {
  description = "Self link (or name) of the VPC network. Normally module.network.network_self_link."
  type        = string
}

variable "subnetwork" {
  description = "Self link (or name) of the subnet for nodes. Normally module.network.subnet_self_link."
  type        = string
}

variable "pods_range_name" {
  description = "Name of the subnet's secondary range for pods."
  type        = string
}

variable "services_range_name" {
  description = "Name of the subnet's secondary range for Services."
  type        = string
}

variable "max_pods_per_node" {
  description = "Default max pods per node. Sets the size of the pod range slice each node takes (110 -> /24, 64 -> /25, 32 -> /26)."
  type        = number
  default     = 110

  validation {
    condition     = var.max_pods_per_node >= 8 && var.max_pods_per_node <= 256
    error_message = "max_pods_per_node must be between 8 and 256."
  }
}

variable "master_ipv4_cidr_block" {
  description = "/28 range for the control plane endpoint. Must not overlap any range in the VPC or anything peered with it."
  type        = string
  default     = "172.16.0.0/28"

  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr_block, 0)) && can(regex("^[0-9.]+/28$", var.master_ipv4_cidr_block))
    error_message = "master_ipv4_cidr_block must be an IPv4 /28, e.g. \"172.16.0.0/28\"."
  }
}

variable "enable_private_endpoint" {
  description = "Disable the public control plane endpoint entirely. kubectl access then needs a path into the VPC (VPN, Interconnect, bastion, or Connect gateway)."
  type        = bool
  default     = false
}

variable "enable_master_global_access" {
  description = "Allow the private control plane endpoint to be reached from any region in the VPC, not just the cluster's region."
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "External CIDRs allowed to reach the public control plane endpoint (office, VPN egress, CI runners). Empty means none."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []

  validation {
    condition     = alltrue([for n in var.master_authorized_networks : can(cidrhost(n.cidr_block, 0))])
    error_message = "Every master_authorized_networks entry needs a valid IPv4 CIDR block."
  }

  validation {
    condition     = alltrue([for n in var.master_authorized_networks : n.cidr_block != "0.0.0.0/0"])
    error_message = "0.0.0.0/0 defeats the purpose of authorized networks. List specific ranges instead."
  }
}

variable "master_webhook_ports" {
  description = "Node ports the control plane may reach for admission webhooks, beyond the 443/10250 GKE already allows. Defaults cover common ones: 8443 (ingress-nginx, Gatekeeper), 9443 (controller-runtime operators), 15017 (Istio). Empty skips the rule."
  type        = list(string)
  default     = ["8443", "9443", "15017"]

  validation {
    condition     = alltrue([for p in var.master_webhook_ports : can(regex("^[0-9]{1,5}(-[0-9]{1,5})?$", p))])
    error_message = "master_webhook_ports entries must be ports (\"8443\") or ranges (\"9000-9100\")."
  }
}

variable "release_channel" {
  description = "GKE release channel: RAPID, REGULAR, STABLE or EXTENDED. Controls how soon new versions arrive; see the README for the trade-offs."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "EXTENDED"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, STABLE or EXTENDED."
  }
}

variable "maintenance_window" {
  description = "Recurring window for automatic upgrades, as RFC 3339 UTC timestamps plus an RFC 5545 RRULE. Only the time of day, duration and recurrence matter. GKE requires at least 48 hours of availability per 32 days; the default (8h on Saturday and Sunday) gives about 64."
  type = object({
    start_time = string
    end_time   = string
    recurrence = string
  })
  default = {
    start_time = "2026-01-03T01:00:00Z"
    end_time   = "2026-01-03T09:00:00Z"
    recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
  }

  validation {
    condition = (
      can(formatdate("YYYY", var.maintenance_window.start_time)) &&
      can(formatdate("YYYY", var.maintenance_window.end_time)) &&
      startswith(var.maintenance_window.recurrence, "FREQ=")
    )
    error_message = "maintenance_window needs RFC 3339 start_time/end_time and an RRULE recurrence such as \"FREQ=WEEKLY;BYDAY=SA,SU\"."
  }
}

variable "maintenance_exclusions" {
  description = "Periods when GKE must not upgrade, e.g. a release freeze. scope is NO_UPGRADES (max 30 days), NO_MINOR_UPGRADES or NO_MINOR_OR_NODE_UPGRADES."
  type = list(object({
    name       = string
    start_time = string
    end_time   = string
    scope      = optional(string, "NO_UPGRADES")
  }))
  default = []

  validation {
    condition     = alltrue([for e in var.maintenance_exclusions : contains(["NO_UPGRADES", "NO_MINOR_UPGRADES", "NO_MINOR_OR_NODE_UPGRADES"], e.scope)])
    error_message = "maintenance_exclusions[*].scope must be NO_UPGRADES, NO_MINOR_UPGRADES or NO_MINOR_OR_NODE_UPGRADES."
  }

  validation {
    condition     = alltrue([for e in var.maintenance_exclusions : can(formatdate("YYYY", e.start_time)) && can(formatdate("YYYY", e.end_time))])
    error_message = "maintenance_exclusions[*].start_time and end_time must be RFC 3339 timestamps."
  }
}

variable "logging_components" {
  description = "Components whose logs go to Cloud Logging. Drop WORKLOADS if container logs are shipped elsewhere (EFK, Loki) to avoid paying twice. An empty list disables Cloud Logging for the cluster."
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]

  validation {
    condition     = length(var.logging_components) == 0 || contains(var.logging_components, "SYSTEM_COMPONENTS")
    error_message = "logging_components must include SYSTEM_COMPONENTS unless it is empty."
  }
}

variable "monitoring_components" {
  description = "Components whose metrics go to Cloud Monitoring."
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS"]

  validation {
    condition     = length(var.monitoring_components) == 0 || contains(var.monitoring_components, "SYSTEM_COMPONENTS")
    error_message = "monitoring_components must include SYSTEM_COMPONENTS unless it is empty."
  }
}

variable "enable_managed_prometheus" {
  description = "Enable Google Cloud Managed Service for Prometheus collection. Off by default on the assumption that an in-cluster Prometheus stack is used; it is billed per sample ingested."
  type        = bool
  default     = false
}

variable "enable_node_local_dns_cache" {
  description = "Run NodeLocal DNSCache on every node. Cuts DNS latency and kube-dns load. Toggling it recreates nodes."
  type        = bool
  default     = true
}

variable "enable_vertical_pod_autoscaling" {
  description = "Enable the Vertical Pod Autoscaler (useful in recommendation-only mode for right-sizing requests)."
  type        = bool
  default     = true
}

variable "autoscaling_profile" {
  description = "Cluster autoscaler profile. OPTIMIZE_UTILIZATION scales down sooner and packs nodes tighter; BALANCED keeps more headroom."
  type        = string
  default     = "BALANCED"

  validation {
    condition     = contains(["BALANCED", "OPTIMIZE_UTILIZATION"], var.autoscaling_profile)
    error_message = "autoscaling_profile must be BALANCED or OPTIMIZE_UTILIZATION."
  }
}

variable "enable_cost_allocation" {
  description = "Enable GKE cost allocation (per-namespace and per-label cost in the billing export)."
  type        = bool
  default     = true
}

variable "database_encryption_key_name" {
  description = "Cloud KMS key for application-layer Secrets encryption, as projects/<p>/locations/<region>/keyRings/<ring>/cryptoKeys/<key>. The GKE service agent needs roles/cloudkms.cryptoKeyEncrypterDecrypter on it. null leaves Secrets with Google-managed encryption only."
  type        = string
  default     = null

  validation {
    condition     = var.database_encryption_key_name == null || can(regex("^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$", var.database_encryption_key_name))
    error_message = "database_encryption_key_name must be a full Cloud KMS key name: projects/<p>/locations/<l>/keyRings/<r>/cryptoKeys/<k>."
  }
}

variable "deletion_protection" {
  description = "Block terraform destroy (and replacement) of the cluster. Set to false and apply before tearing down."
  type        = bool
  default     = true
}

variable "node_service_account_id" {
  description = "Account ID for the node service account. null derives it as <name>-nodes, which must fit in 30 characters."
  type        = string
  default     = null
}

variable "node_service_account_roles" {
  description = "Project roles for the node service account. roles/container.defaultNodeServiceAccount covers logging, monitoring and metadata; Artifact Registry reader lets nodes pull private images (grant it per repository instead if you want it tighter)."
  type        = list(string)
  default = [
    "roles/container.defaultNodeServiceAccount",
    "roles/artifactregistry.reader",
  ]

  validation {
    condition     = length(setintersection(var.node_service_account_roles, ["roles/owner", "roles/editor"])) == 0
    error_message = "Do not grant basic roles (roles/owner, roles/editor) to the node service account."
  }
}

variable "node_network_tags" {
  description = "Network tags added to every node, e.g. for firewall rules such as IAP SSH."
  type        = list(string)
  default     = []
}

variable "node_pools" {
  description = <<-EOT
    Node pools keyed by pool name. min_count/max_count are per zone, so a regional
    cluster across three zones with min_count = 1 runs at least three nodes.
    Set spot = true for Spot VMs, and taint those pools so only workloads that
    tolerate preemption land there.
  EOT
  type = map(object({
    machine_type    = optional(string, "e2-standard-4")
    image_type      = optional(string, "COS_CONTAINERD")
    disk_type       = optional(string, "pd-balanced")
    disk_size_gb    = optional(number, 100)
    min_count       = optional(number, 1)
    max_count       = optional(number, 3)
    spot            = optional(bool, false)
    max_surge       = optional(number, 1)
    max_unavailable = optional(number, 0)
    labels          = optional(map(string), {})
    network_tags    = optional(list(string), [])
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))

  validation {
    condition     = length(var.node_pools) > 0
    error_message = "Define at least one node pool."
  }

  validation {
    condition     = alltrue([for name in keys(var.node_pools) : can(regex("^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$", name))])
    error_message = "Node pool names must be 1-40 chars of lowercase letters, digits and hyphens, starting with a letter."
  }

  validation {
    condition = alltrue([
      for p in var.node_pools :
      p.min_count >= 0 && p.max_count >= 1 && p.min_count <= p.max_count
    ])
    error_message = "Each node pool needs 0 <= min_count <= max_count and max_count >= 1."
  }

  validation {
    condition     = alltrue([for p in var.node_pools : p.max_surge >= 0 && p.max_unavailable >= 0 && p.max_surge + p.max_unavailable > 0])
    error_message = "max_surge and max_unavailable must be >= 0 and at least one of them > 0."
  }

  validation {
    condition     = alltrue([for p in var.node_pools : contains(["COS_CONTAINERD", "UBUNTU_CONTAINERD"], p.image_type)])
    error_message = "image_type must be COS_CONTAINERD or UBUNTU_CONTAINERD."
  }

  validation {
    condition     = alltrue([for p in var.node_pools : p.disk_size_gb >= 20])
    error_message = "disk_size_gb must be at least 20."
  }

  validation {
    condition = alltrue(flatten([
      for p in var.node_pools : [
        for t in p.taints : contains(["NO_SCHEDULE", "PREFER_NO_SCHEDULE", "NO_EXECUTE"], t.effect)
      ]
    ]))
    error_message = "Taint effect must be NO_SCHEDULE, PREFER_NO_SCHEDULE or NO_EXECUTE."
  }
}

variable "labels" {
  description = "Labels for the cluster and for node VMs/disks (as GCE resource labels). managed-by=terraform is always added."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.labels :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "Label keys must start with a lowercase letter; keys and values may contain only lowercase letters, digits, '_' and '-' (max 63 chars)."
  }
}
