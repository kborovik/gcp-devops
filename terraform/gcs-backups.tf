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

###############################################################################
# Data Disk Snapshot Policy
###############################################################################

resource "google_compute_resource_policy" "data_disk_snapshots" {
  name   = "data-disk-daily-snapshots"
  region = var.google_region

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "02:00"
      }
    }

    retention_policy {
      max_retention_days    = 14
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }
  }

  depends_on = [google_project_service.main]
}

resource "google_compute_disk_resource_policy_attachment" "data_disk_snapshots" {
  name = google_compute_resource_policy.data_disk_snapshots.name
  disk = google_compute_disk.mailpilot_data.name
  zone = "${var.google_region}-b"
}
