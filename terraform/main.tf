terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

resource "google_storage_bucket" "postgres_testing_bucket" {
  name                        = var.bucket_name
  location                    = var.location
  force_destroy               = false
  uniform_bucket_level_access = true
}

# Create a service account
resource "google_service_account" "pgbackrest_service_account" {
  account_id   = "pgbackrest-sa"
  display_name = "Service Account for pgBackRest backups"
}

# Grant the service account access to the bucket
resource "google_storage_bucket_iam_member" "pgbackrest_bucket_access" {
  bucket = google_storage_bucket.postgres_testing_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.pgbackrest_service_account.email}"
}

# Generate a key for the service account
resource "google_service_account_key" "pgbackrest_service_account_key" {
  service_account_id = google_service_account.pgbackrest_service_account.id
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Write the service account key into the gitignored secrets/ dir (mounted at run)
resource "local_file" "pgbackrest_service_account_key_file" {
  filename = "${path.module}/../secrets/service-account-key.json"
  content  = base64decode(google_service_account_key.pgbackrest_service_account_key.private_key)
}

# Render the GCS pgbackrest config (bucket baked in by Terraform, never templated
# at runtime) into the gitignored gcp config dir that run-database.sh mounts.
resource "local_file" "gcp_pgbackrest_conf" {
  filename = "${path.module}/../docker/config/gcp/pgbackrest.conf"
  content = templatefile("${path.module}/templates/pgbackrest.conf.tftpl", {
    bucket_name = google_storage_bucket.postgres_testing_bucket.name
  })
}

# The GCS source archives to the plain demo-gcp stanza (mirrors local/archive.conf)
resource "local_file" "gcp_archive_conf" {
  filename = "${path.module}/../docker/config/gcp/archive.conf"
  content  = "archive_command = 'pgbackrest --stanza=demo-gcp archive-push %p'\n"
}

output "bucket_name" {
  value = google_storage_bucket.postgres_testing_bucket.name
}

output "service_account_email" {
  value = google_service_account.pgbackrest_service_account.email
}
