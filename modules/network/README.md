# network

A custom-mode VPC with one regional subnet sized for GKE: a primary range for
nodes and secondary ranges for pods and Services. Also creates a Cloud Router,
Cloud NAT and a small set of firewall rules.

```hcl
module "network" {
  source = "../../modules/network"

  project_id    = "my-dev-project"
  name          = "platform-dev"
  region        = "us-central1"
  subnet_cidr   = "10.10.0.0/20"
  pods_cidr     = "10.16.0.0/14"
  services_cidr = "10.20.0.0/20"

  enable_iap_ssh      = true
  iap_ssh_target_tags = ["platform-dev-gke-node"]

  labels = { env = "dev", team = "platform", cost-center = "cc-0000" }
}
```

What to know:

- **Private Google Access** is always on, so nodes without external IPs reach
  Google APIs directly and that traffic does not count against Cloud NAT.
- **Cloud NAT** covers only this subnet (all ranges, so pods too) and uses
  dynamic port allocation with `ERRORS_ONLY` logging. Set `nat_ip_count` for
  static egress IPs.
- **Firewall**: GKE manages its own cluster rules. This module adds an
  explicit, logged deny-all ingress rule at priority 65534 (`log_denied_ingress`)
  and, if `enable_iap_ssh` is set, SSH from the IAP range `35.235.240.0/20` to
  the given tags only.
- **Flow logs** are on, sampled at 25% with 5-minute aggregation. Adjust
  `flow_logs` to trade visibility for log volume.
- A precondition fails the plan if the subnet, pod and service ranges overlap.

See [`variables.tf`](variables.tf) and [`outputs.tf`](outputs.tf) for every
input and output.
