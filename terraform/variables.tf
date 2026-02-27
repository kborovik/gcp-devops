###############################################################################
# General project variables
###############################################################################

variable "google_project" {
  description = "GCP Project Id"
  type        = string
  default     = null
}

variable "google_region" {
  description = "Default GCP region"
  type        = string
  default     = null
}

variable "gce_schedule" {
  description = "Schedule for GCE instances"
  type        = string
  default     = null
}

variable "allow_sa_key_creation" {
  description = "Override org policy to allow service account key creation"
  type        = bool
  default     = false
}

variable "allow_external_iam_members" {
  description = "Override org policy to allow IAM members from outside the organization (required for Gmail push notifications)"
  type        = bool
  default     = false
}
