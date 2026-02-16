###############################################################################
# GCS Bucket for pgBackRest Backups
###############################################################################

resource "google_storage_bucket" "backups" {
  name     = "backups-${var.google_project}"
  location = var.google_region
  project  = var.google_project

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.main]
}

resource "google_storage_bucket_iam_member" "backups_writer" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.mailpilot.member
}
