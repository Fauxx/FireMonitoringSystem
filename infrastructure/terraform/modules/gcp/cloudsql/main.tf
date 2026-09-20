# ── Cloud SQL Instance (The Terminal)
resource "google_sql_database_instance" "main" {
  name             = var.instance_name
  project          = var.project_id
  region           = var.region
  database_version = var.database_version

  # Prevent accidental deletion in production, but allow for dev/learning
  deletion_protection = false

  settings {
    tier = var.tier

    # Enable IAM database authentication for the proxy
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    ip_configuration {
      ipv4_enabled = true
      # We don't restrict authorized_networks here because the Auth Proxy uses IAM
      # over the public IP to authenticate and encrypt securely!
    }
  }
}

# ── Logical Databases (The Destinations)
resource "google_sql_database" "logical_dbs" {
  for_each = toset(var.database_names)
  
  name     = each.key
  project  = var.project_id
  instance = google_sql_database_instance.main.name
}

# ── IAM Database User (The Boarding Pass)
# When IAM Auth is enabled, we create a user mapped to the exact Service Account email!
resource "google_sql_user" "iam_user" {
  name     = trimsuffix(var.gke_service_account_email, ".gserviceaccount.com")
  instance = google_sql_database_instance.main.name
  project  = var.project_id
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# ── IAM Permission (The Security Guard)
# Grants the GKE pod the actual Google Cloud permission to connect to this DB
resource "google_project_iam_member" "db_client_role" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${var.gke_service_account_email}"
}

# ── Instance User Role
# Required for IAM users to log in to Postgres
resource "google_project_iam_member" "db_instance_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${var.gke_service_account_email}"
}
