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
      max_retention_days    = 3
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
