# workload-identity

One GCP service account that a specific Kubernetes service account is allowed
to impersonate (`roles/iam.workloadIdentityUser`), plus optional project-level
roles for it.

```hcl
module "orders_api_identity" {
  source = "../../modules/workload-identity"

  project_id                 = "my-dev-project"
  account_id                 = "platform-dev-orders-api"
  namespace                  = "orders"
  kubernetes_service_account = "orders-api"
  project_roles              = ["roles/cloudsql.client"]

  # From the gke module: also makes the binding wait until the cluster (and
  # with it the identity pool) exists.
  workload_identity_pool = module.gke.workload_identity_pool
}
```

Then annotate the Kubernetes service account with the `kubernetes_annotation`
output:

```yaml
metadata:
  annotations:
    iam.gke.io/gcp-service-account: platform-dev-orders-api@my-dev-project.iam.gserviceaccount.com
```

Notes:

- Prefer resource-level grants where possible (one bucket, one secret, one
  Pub/Sub topic). Use the `member` output with the matching
  `google_*_iam_member` resource instead of a project role.
- Validation rejects `roles/owner` and `roles/editor`.
- The module does not create the Kubernetes service account. That usually
  belongs with the workload's Helm chart or manifests.

See [`variables.tf`](variables.tf) and [`outputs.tf`](outputs.tf) for every
input and output.
