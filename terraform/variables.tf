variable "project" {
  description = "GCP project for the bucket (set in terraform.tfvars)"
}

variable "bucket_name" {
  description = "Globally-unique GCS bucket name (set in terraform.tfvars)"
}

variable "region" {
  description = "GCP provider region (override in terraform.tfvars)"
  default     = "us-central1"
}

variable "location" {
  description = "GCS bucket location - region or multi-region (override in terraform.tfvars)"
  default     = "US"
}
