###############################################################################
# Terraform Outputs
###############################################################################

output "ansible_hosts" {
  description = "Map of host names to their public IP addresses"
  value = [
    {
      name = google_compute_instance.mailpilot.name
      ip   = google_compute_instance.mailpilot.network_interface[0].access_config[0].nat_ip
      dns  = "${local.dep_env}.${local.domain}"
    }
  ]
}
