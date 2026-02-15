###############################################################################
# Enable GCP Project Services
###############################################################################

locals {
  google_project_services = [
    "aiplatform.googleapis.com",
    "calendar-json.googleapis.com",
    "cloudcommerceconsumerprocurement.googleapis.com",
    "cloudscheduler.googleapis.com",
    "compute.googleapis.com",
    "docs.googleapis.com",
    "drive.googleapis.com",
    "forms.googleapis.com",
    "gmail.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "oslogin.googleapis.com",
    "people.googleapis.com",
    "pubsub.googleapis.com",
    "orgpolicy.googleapis.com",
    "secretmanager.googleapis.com",
    "sheets.googleapis.com",
    "storage.googleapis.com",
  ]
}

resource "google_project_service" "main" {
  for_each                   = toset(local.google_project_services)
  service                    = each.key
  project                    = var.google_project
  disable_dependent_services = true
  disable_on_destroy         = false
}
