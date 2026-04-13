###############################################################################
# Gemini API Key
###############################################################################

resource "google_apikeys_key" "gemini" {
  name         = "gemini"
  display_name = "Gemini API Key"
  project      = var.google_project

  restrictions {
    api_targets {
      service = "generativelanguage.googleapis.com"
    }
  }

  depends_on = [google_project_service.main]
}

###############################################################################
# Gemini API Key Secret
###############################################################################

resource "google_secret_manager_secret" "gemini_api_key" {
  secret_id = "gemini-api-key"

  replication {
    auto {}
  }

  depends_on = [
    google_project_service.main,
    google_apikeys_key.gemini,
  ]
}

resource "google_secret_manager_secret_version" "gemini_api_key" {
  secret      = google_secret_manager_secret.gemini_api_key.id
  secret_data = google_apikeys_key.gemini.key_string
  depends_on  = [google_project_service.main]
}
