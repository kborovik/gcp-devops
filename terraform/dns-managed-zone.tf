###############################################################################
# DNS Zone
###############################################################################

locals {
  dep_env = regex("^[^-]+-(.+)$", var.google_project)[0]
  domain  = "lab5.ca"
}

data "cloudflare_zone" "public" {
  filter = {
    name = local.domain
  }
}
