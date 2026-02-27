###############################################################################
# Service Account
###############################################################################

resource "google_service_account" "mailpilot" {
  account_id   = "mailpilot"
  display_name = "MailPilot"
  depends_on   = [google_project_service.main]
}

resource "google_project_iam_member" "mailpilot" {
  for_each = toset([
    "roles/aiplatform.user",
    "roles/compute.instanceAdmin.v1",
    "roles/consumerprocurement.entitlementManager",
    "roles/iam.serviceAccountTokenCreator",
    "roles/logging.logWriter",
    "roles/logging.viewer",
    "roles/monitoring.metricWriter",
    "roles/opsconfigmonitoring.resourceMetadata.writer",
    "roles/pubsub.admin",
    "roles/secretmanager.secretAccessor",
    "roles/storage.objectViewer",
  ])

  project    = var.google_project
  member     = google_service_account.mailpilot.member
  role       = each.value
  depends_on = [google_project_service.main]
}

resource "google_service_account_key" "mailpilot" {
  service_account_id = google_service_account.mailpilot.name
  depends_on         = [google_org_policy_policy.allow_sa_key_creation, google_project_service.main]
}

###############################################################################
# Service Account Key Secret
###############################################################################

resource "google_secret_manager_secret" "mailpilot" {
  secret_id = "${google_service_account.mailpilot.account_id}-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.main]
}

resource "google_secret_manager_secret_version" "mailpilot" {
  secret      = google_secret_manager_secret.mailpilot.id
  secret_data = google_service_account_key.mailpilot.private_key
  depends_on  = [google_project_service.main]
}
