terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # State is local by default so the example runs without extra setup. For
  # anything shared, use a GCS bucket with object versioning enabled:
  #
  # backend "gcs" {
  #   bucket = "<your-state-bucket>"
  #   prefix = "gke-platform/dev"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
