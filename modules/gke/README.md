# gke

A private GKE Standard cluster (regional when `location` is a region), its node
pools, a least-privilege node service account, and a firewall rule for
control-plane-to-node admission webhooks.

```hcl
module "gke" {
  source = "../../modules/gke"

  project_id = "my-dev-project"
  name       = "platform-dev-gke"
  location   = "us-central1"

  network             = module.network.network_self_link
  subnetwork          = module.network.subnet_self_link
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  master_authorized_networks = [
    { cidr_block = "203.0.113.0/24", display_name = "office-vpn" },
  ]

  node_pools = {
    general = { machine_type = "e2-standard-4", min_count = 1, max_count = 3 }
    spot-batch = {
      spot      = true
      min_count = 0
      max_count = 5
      taints    = [{ key = "cloud.google.com/gke-spot", value = "true", effect = "NO_SCHEDULE" }]
    }
  }

  labels = { env = "dev", team = "platform", cost-center = "cc-0000" }
}
```

Cluster defaults:

| Setting | Value | Change with |
|---|---|---|
| Nodes | private (no external IPs) | fixed |
| Control plane endpoint | public, restricted to authorized networks | `enable_private_endpoint`, `master_authorized_networks` |
| Dataplane | V2 (`ADVANCED_DATAPATH`), NetworkPolicy enforced | fixed (set at creation only) |
| Workload Identity | `<project>.svc.id.goog`, `GKE_METADATA` on all pools | fixed |
| Release channel | `REGULAR` | `release_channel` |
| Maintenance window | Sat and Sun 01:00–09:00 UTC | `maintenance_window`, `maintenance_exclusions` |
| Shielded nodes | secure boot + integrity monitoring | fixed |
| Logging / monitoring | system + workloads / system | `logging_components`, `monitoring_components` |
| Managed Prometheus | off | `enable_managed_prometheus` |
| NodeLocal DNSCache, VPA, cost allocation | on | `enable_*` variables |
| Secrets encryption with Cloud KMS | off | `database_encryption_key_name` |
| Deletion protection | on | `deletion_protection` |

Notes:

- `min_count` and `max_count` are **per zone**. Three zones with `min_count = 1`
  means three nodes.
- Node pools always auto-repair and auto-upgrade (required on a release
  channel) and surge-upgrade with `max_surge = 1`, `max_unavailable = 0` by
  default.
- Spot pools use `location_policy = "ANY"`. A `check` block warns if a Spot
  pool has no taints.
- The node service account gets `roles/container.defaultNodeServiceAccount` and
  `roles/artifactregistry.reader` (`node_service_account_roles`). Its ID defaults
  to `<name>-nodes`; set `node_service_account_id` if that exceeds 30 characters.
- `master_webhook_ports` (default 8443, 9443, 15017) opens those ports from the
  control plane range to nodes, targeted by the node service account.
- Some node pool changes are rolled out to nodes in place; others replace the
  whole pool (`terraform plan` says "forces replacement"). For those, add a new
  pool under a new key, move workloads over (cordon and drain), then remove the
  old one.

See [`variables.tf`](variables.tf) and [`outputs.tf`](outputs.tf) for every
input and output.
