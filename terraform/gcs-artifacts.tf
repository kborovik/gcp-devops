###############################################################################
# GCS Bucket for Pilot Artifacts
###############################################################################

resource "google_storage_bucket" "artifacts" {
  name     = "artifacts-${var.google_project}"
  location = var.google_region
  project  = var.google_project

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.main]
}
