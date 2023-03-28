terraform {
  required_version = ">= 1.0"
  backend "local" {}
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
  }
}

provider "google" {
    project = var.project
    region = var.region
}


#
# Infra
#

resource "google_project_service" "project" {
    for_each = toset([
        "compute.googleapis.com",
        "iam.serviceAccounts.create"
    ])
    project = var.project
    service = each.key
}

resource "google_project_iam_member" "permissions" {
    for_each = toset([
        "roles/bigquery.admin",
        "roles/storage.admin",
        "roles/storage.objectAdmin"
    ])
    project = var.project
    role    = each.key
    member  = google_service_account.compute_engine_sa.email
}

resource "google_service_account" "compute_engine_sa" {
    project = var.project
    account_id   = "compute-engine-sa"
    display_name = "Service Account for Compute Engine"

    depends_on = [
      google_project_service.project
    ]
}

resource "google_compute_instance" "prefect" {
    name         = "prefect"
    machine_type = "e2-medium"
    deletion_protection = false

    boot_disk {
      initialize_params {
        image = "ubuntu-os-cloud/ubuntu-1804-lts"
      }
    }

    network_interface {
        network = "default"
    } 

    service_account {
        email  = google_service_account.compute_engine_sa.email
        scopes = ["cloud-platform"]
    }

    depends_on = [
        google_project_service.project
    ]
}

resource "google_storage_bucket" "data-lake-bucket" {
  name          = "de-zoomcamp-project-data-lake-1234"
  location      = var.region

  storage_class = "STANDARD"
  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30  // days
    }
  }

  force_destroy = true
}

resource "google_storage_bucket" "prefect-bucket" {
  name          = "de-zoomcamp-project-prefect-code-1234"
  location      = var.region

  storage_class = "STANDARD"
  uniform_bucket_level_access = true

  versioning {
    enabled     = true
  }

  force_destroy = true
}

resource "google_bigquery_dataset" "datawarehous" {
  dataset_id = "datawarehous"
  project    = var.project
  location   = var.region
}

resource "google_bigquery_dataset" "dbt" {
  dataset_id = "dbt"
  project    = var.project
  location   = var.region
}