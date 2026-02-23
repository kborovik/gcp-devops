###############################################################################
# Compute Resource Policies
###############################################################################

resource "google_project_iam_member" "mailpilot_stop_start" {
  project    = var.google_project
  member     = "serviceAccount:service-${data.google_project.current.number}@compute-system.iam.gserviceaccount.com"
  role       = "roles/compute.instanceAdmin.v1"
  depends_on = [google_project_service.main]
}

resource "google_compute_resource_policy" "mailpilot_stop_start" {
  name        = "stop-start"
  description = "Start GCE at 8:00 every day and stop at 20:00 every day"
  region      = var.google_region

  instance_schedule_policy {
    time_zone = "America/Toronto"
    vm_start_schedule {
      schedule = "0 8 * * 1-5"
    }
    vm_stop_schedule {
      schedule = "0 20 * * *"
    }
  }

  depends_on = [google_project_service.main]
}

resource "google_compute_resource_policy" "mailpilot_stop_only" {
  name        = "stop-only"
  description = "Stop GCE at 20:00 every day"
  region      = var.google_region

  instance_schedule_policy {
    time_zone = "America/Toronto"
    vm_stop_schedule {
      schedule = "0 20 * * *"
    }
  }

  depends_on = [google_project_service.main]
}

###############################################################################
# Data Disk
###############################################################################

resource "google_compute_disk" "mailpilot_data" {
  name       = "mailpilot-1-pgsql"
  type       = "pd-balanced"
  zone       = "${var.google_region}-b"
  size       = 20
  depends_on = [google_project_service.main]

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# GCE Instance
###############################################################################

resource "google_compute_address" "mailpilot_ipv4" {
  name         = "mailpilot-1-ipv4"
  address_type = "EXTERNAL"
  depends_on   = [google_project_service.main]
}

resource "google_compute_instance" "mailpilot" {
  name                      = "mailpilot-1"
  machine_type              = "e2-medium"
  zone                      = "${var.google_region}-b"
  allow_stopping_for_update = true

  resource_policies = [
    var.gce_schedule == "stop_only" ? google_compute_resource_policy.mailpilot_stop_only.id : google_compute_resource_policy.mailpilot_stop_start.id
  ]

  metadata = {
    enable-osconfig         = "TRUE"
    enable-guest-attributes = "TRUE"
    ssh-keys                = "ubuntu:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE8MDQfvLDhGVy6KnLSsz791MNG3hWN1W1Y8hLqadkvA ubuntu"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-2404-lts-amd64"
      type  = "pd-balanced"
      size  = 20
    }
  }

  attached_disk {
    device_name = google_compute_disk.mailpilot_data.name
    source      = google_compute_disk.mailpilot_data.self_link
    mode        = "READ_WRITE"
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.subnet1.id
    nic_type   = "GVNIC"

    access_config {
      nat_ip       = google_compute_address.mailpilot_ipv4.address
      network_tier = "PREMIUM"
    }
  }

  service_account {
    email = google_service_account.mailpilot.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  depends_on = [
    google_compute_address.mailpilot_ipv4,
    google_compute_disk.mailpilot_data,
    google_compute_resource_policy.mailpilot_stop_only,
    google_compute_resource_policy.mailpilot_stop_start,
    google_project_service.main,
  ]

  lifecycle {
    ignore_changes = [
      boot_disk[0].initialize_params[0].image
    ]
  }
}

###############################################################################
# DNS Record Sets
###############################################################################

resource "cloudflare_dns_record" "mailpilot_ipv4" {
  zone_id = data.cloudflare_zone.public.zone_id
  name    = "${local.dep_env}.${data.cloudflare_zone.public.name}"
  type    = "A"
  content = google_compute_address.mailpilot_ipv4.address
  ttl     = 300
}
