###############################################################################
# Organization Policy Overrides
###############################################################################

resource "google_org_policy_policy" "allow_sa_key_creation" {
  count  = var.allow_sa_key_creation ? 1 : 0
  name   = "projects/${var.google_project}/policies/iam.disableServiceAccountKeyCreation"
  parent = "projects/${var.google_project}"

  spec {
    rules {
      enforce = "FALSE"
    }
  }

  depends_on = [google_project_service.main]
}
