variable "project_id" {
  description = "ID of the GCP project that owns the network."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (6-30 chars, lowercase letters, digits and hyphens)."
  }
}

variable "name" {
  description = "Name prefix for every resource in this module, e.g. \"platform-dev\". Resources are named <name>-vpc, <name>-router, <name>-nat, and so on."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,28}[a-z0-9])?$", var.name))
    error_message = "name must be 1-30 chars, start with a letter, and contain only lowercase letters, digits and hyphens."
  }
}

variable "region" {
  description = "Region for the subnet, Cloud Router and Cloud NAT, e.g. \"us-central1\"."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region must be a region name such as \"us-central1\", not a zone."
  }
}

variable "subnet_cidr" {
  description = "Primary range of the subnet, used for node IPs. A /20 gives about 4,000 nodes."
  type        = string

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0)) && can(regex("^[0-9.]+/[0-9]+$", var.subnet_cidr))
    error_message = "subnet_cidr must be an IPv4 CIDR block, e.g. \"10.10.0.0/20\"."
  }
}

variable "pods_cidr" {
  description = "Secondary range for pod IPs. GKE gives each node a slice sized from max pods per node (a /24 for the default of 110), so a /14 supports about 1,000 nodes."
  type        = string

  validation {
    condition     = can(cidrhost(var.pods_cidr, 0)) && can(regex("^[0-9.]+/[0-9]+$", var.pods_cidr))
    error_message = "pods_cidr must be an IPv4 CIDR block, e.g. \"10.16.0.0/14\"."
  }
}

variable "services_cidr" {
  description = "Secondary range for Kubernetes Service ClusterIPs. A /20 allows about 4,000 Services."
  type        = string

  validation {
    condition     = can(cidrhost(var.services_cidr, 0)) && can(regex("^[0-9.]+/[0-9]+$", var.services_cidr))
    error_message = "services_cidr must be an IPv4 CIDR block, e.g. \"10.20.0.0/20\"."
  }
}

variable "pods_range_name" {
  description = "Name of the secondary range for pods. Passed to the GKE module."
  type        = string
  default     = "pods"

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.pods_range_name))
    error_message = "pods_range_name must be 1-63 chars of lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "services_range_name" {
  description = "Name of the secondary range for Services. Passed to the GKE module."
  type        = string
  default     = "services"

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.services_range_name))
    error_message = "services_range_name must be 1-63 chars of lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "flow_logs" {
  description = "VPC Flow Logs settings for the subnet. Flow logs are billed as log ingestion, so sampling is the main cost control."
  type = object({
    enabled              = optional(bool, true)
    aggregation_interval = optional(string, "INTERVAL_5_MIN")
    sampling             = optional(number, 0.25)
    metadata             = optional(string, "INCLUDE_ALL_METADATA")
  })
  default = {}

  validation {
    condition = contains(
      ["INTERVAL_5_SEC", "INTERVAL_30_SEC", "INTERVAL_1_MIN", "INTERVAL_5_MIN", "INTERVAL_10_MIN", "INTERVAL_15_MIN"],
      var.flow_logs.aggregation_interval,
    )
    error_message = "flow_logs.aggregation_interval must be one of INTERVAL_5_SEC, INTERVAL_30_SEC, INTERVAL_1_MIN, INTERVAL_5_MIN, INTERVAL_10_MIN, INTERVAL_15_MIN."
  }

  validation {
    condition     = var.flow_logs.sampling > 0 && var.flow_logs.sampling <= 1
    error_message = "flow_logs.sampling must be greater than 0 and at most 1."
  }

  validation {
    condition     = contains(["INCLUDE_ALL_METADATA", "EXCLUDE_ALL_METADATA"], var.flow_logs.metadata)
    error_message = "flow_logs.metadata must be INCLUDE_ALL_METADATA or EXCLUDE_ALL_METADATA."
  }
}

variable "nat_ip_count" {
  description = "Number of static external IPs to reserve for Cloud NAT. 0 lets Google allocate (and change) egress IPs automatically."
  type        = number
  default     = 0

  validation {
    condition     = var.nat_ip_count >= 0 && var.nat_ip_count <= 16 && floor(var.nat_ip_count) == var.nat_ip_count
    error_message = "nat_ip_count must be a whole number between 0 and 16."
  }
}

variable "nat_min_ports_per_vm" {
  description = "Minimum NAT source ports per VM. With dynamic port allocation this must be a power of two, at least 32."
  type        = number
  default     = 64

  validation {
    condition     = contains([32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768], var.nat_min_ports_per_vm)
    error_message = "nat_min_ports_per_vm must be a power of two between 32 and 32768."
  }
}

variable "nat_max_ports_per_vm" {
  description = "Maximum NAT source ports per VM. Must be a power of two and larger than nat_min_ports_per_vm."
  type        = number
  default     = 4096

  validation {
    condition     = contains([64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536], var.nat_max_ports_per_vm)
    error_message = "nat_max_ports_per_vm must be a power of two between 64 and 65536."
  }
}

variable "nat_log_filter" {
  description = "Which Cloud NAT events to log. ERRORS_ONLY catches port exhaustion (OUT_OF_RESOURCES drops) without logging every connection."
  type        = string
  default     = "ERRORS_ONLY"

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.nat_log_filter)
    error_message = "nat_log_filter must be ERRORS_ONLY, TRANSLATIONS_ONLY or ALL."
  }
}

variable "log_denied_ingress" {
  description = "Create an explicit, logged deny-all ingress rule at priority 65534. Traffic is denied either way; this only makes the drops visible."
  type        = bool
  default     = true
}

variable "enable_iap_ssh" {
  description = "Allow SSH (tcp/22) from the IAP TCP forwarding range to instances carrying iap_ssh_target_tags."
  type        = bool
  default     = false
}

variable "iap_ssh_target_tags" {
  description = "Network tags the IAP SSH rule applies to. Required when enable_iap_ssh is true."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for t in var.iap_ssh_target_tags : can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", t))])
    error_message = "Network tags must be 1-63 chars of lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "labels" {
  description = "Labels applied to every resource in this module that supports them (currently the static NAT IPs; VPCs, subnets, routers and firewall rules have no labels in the GCP API). managed-by=terraform is always added."
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
