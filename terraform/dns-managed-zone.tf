###############################################################################
# DNS Zone
###############################################################################

locals {
  dep_env = regex("-([^-]+)$", var.google_project)[0]
}

data "cloudflare_zone" "public" {
  filter = {
    name = "mailpilot.ca"
  }
}
