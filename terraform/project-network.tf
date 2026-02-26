###############################################################################
# Management Network configuration
###############################################################################

data "google_compute_network" "main" {
  name = "main"
}

data "google_compute_subnetwork" "subnet1" {
  name   = var.google_region
  region = var.google_region
}

###############################################################################
# Firewall Rules
###############################################################################

resource "google_compute_firewall" "any_ipv4" {
  name        = "any-sources-ipv4"
  description = "Allow any IPv4 sources"
  network     = data.google_compute_network.main.id
  priority    = 200
  direction   = "INGRESS"

  source_ranges = [
    "0.0.0.0/0",
  ]

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  allow {
    protocol = "udp"
    ports    = ["443", "41641"]
  }

  allow {
    protocol = "icmp"
  }

  depends_on = [google_project_service.main]
}
