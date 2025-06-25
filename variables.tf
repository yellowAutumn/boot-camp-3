// Variables for regions, VPC names, and project
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "regions" {
  description = "List of GCP regions for VPCs"
  type        = list(string)
  default     = ["us-central1", "us-east1"]
}

variable "vpc_names" {
  description = "Names of the VPCs to create"
  type        = list(string)
  default     = ["vpc-central", "vpc-east"]
}

variable "bucket_names" {
  description = "Names of the GCS buckets to create in each region"
  type        = list(string)
  default     = ["bootcamp-central-bucket", "bootcamp-east-bucket"]
}

variable "firestore_location" {
  description = "Location for Firestore (multi-region)"
  type        = string
  default     = "nam5"
}


