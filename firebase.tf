resource "google_project_service" "resource_manager" {
    provider = google
    project = local.project_id
    service = "cloudresourcemanager.googleapis.com"
    disable_dependent_services = true
}

resource "google_project_service" "firebase" {
    provider = google
    project = local.project_id
    service = "firebase.googleapis.com"
    disable_dependent_services = true
}

resource "google_firebase_project" "hellogke" {
  provider = google-beta
  project  = local.project_id
}

resource "google_firebase_web_app" "hellogke" {
    provider = google-beta
    project = local.project_id
    display_name = "Hello GKE Web App"
    depends_on = [
      google_project_service.firebase
    ]
}

data "google_firebase_web_app_config" "hellogke" {
  provider   = google-beta
  web_app_id = google_firebase_web_app.hellogke.app_id
  depends_on = [
      google_project_service.firebase
    ]
}

resource "google_storage_bucket" "hellogke-firebase" {
    provider = google-beta
    name     = "hellogke-firebase-${local.project_id}"
    location = "europe-west1"
}

resource "google_storage_bucket_object" "hellogke-config" {
    provider = google-beta
    bucket = google_storage_bucket.hellogke-firebase.name
    name = "firebase-config.json"

    content = jsonencode({
        appId              = google_firebase_web_app.hellogke.app_id
        apiKey             = data.google_firebase_web_app_config.hellogke.api_key
        authDomain         = data.google_firebase_web_app_config.hellogke.auth_domain
        databaseURL        = lookup(data.google_firebase_web_app_config.hellogke, "database_url", "")
        storageBucket      = lookup(data.google_firebase_web_app_config.hellogke, "storage_bucket", "")
        messagingSenderId  = lookup(data.google_firebase_web_app_config.hellogke, "messaging_sender_id", "")
        measurementId      = lookup(data.google_firebase_web_app_config.hellogke, "measurement_id", "")
    })
}

output firebase_config_bucket {
    value = google_storage_bucket.hellogke-firebase.name
    description = "Bucket where Firebase config is stored"
}

output firebase_web_app_config {
    value = google_storage_bucket_object.hellogke-config.source
    description = "Firebase configuration file"
}

output firebase_app_id {
    value = google_firebase_web_app.hellogke.app_id
    description = "Firebase application Id"
}

# Authentication management still misses a Terraform API, so you have to enable it manually in the Firebase Console. 
# Firebase authentication is the only thing we found no way to automate.