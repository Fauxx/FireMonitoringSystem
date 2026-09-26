locals {
  cluster_name = "gke-firemonitoring-dev-01"
  env          = "dev"
}

# ── VPC
resource "google_compute_network" "main" {
  project                 = var.project_id
  name                    = "vpc-firemonitoring-dev"
  auto_create_subnetworks = false
}

# ── Subnet
resource "google_compute_subnetwork" "gke" {
  project       = var.project_id
  region        = var.region
  name          = "snet-firemonitoring-gke-dev"
  network       = google_compute_network.main.id
  ip_cidr_range = "10.10.1.0/24"

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.48.0.0/14"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.52.0.0/20"
  }

  private_ip_google_access = true
}

# ── Firewall
resource "google_compute_firewall" "allow_web" {
  project   = var.project_id
  name      = "fw-firemonitoring-dev-allow-web"
  network   = google_compute_network.main.id
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-${local.cluster_name}"]
}

# ── GKE Node Service Account
resource "google_service_account" "gke_node" {
  project      = var.project_id
  account_id   = "sa-gke-node-dev"
  display_name = "GKE Node Pool SA — Dev"
}

resource "google_project_iam_member" "node_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

# ── Artifact Registry
resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.region
  repository_id = "firemonitoring-dev"
  format        = "DOCKER"
  description   = "Container images for FireMonitoringSystem dev"
}

# ── GKE Cluster
module "cluster" {
  source              = "../../../modules/gke/cluster"
  project_id          = var.project_id
  region              = var.region
  zone                = "${var.region}-a"
  cluster_name        = local.cluster_name
  network_id          = google_compute_network.main.id
  subnet_id           = google_compute_subnetwork.gke.id
  pods_range_name     = "pods"
  services_range_name = "services"
  min_node_count      = 1
  max_node_count      = 3
  machine_type        = "e2-medium"
  disk_size_gb        = 50
  node_sa_email       = google_service_account.gke_node.email
}



# ── API Database Client Service Account
resource "google_service_account" "db_client" {
  project      = var.project_id
  account_id   = "sa-api-database-client"
  display_name = "Database Client for API Pods (Dev)"
}

# ── Cloud SQL Database
module "database" {
  source = "../../../modules/gcp/cloudsql"

  project_id    = var.project_id
  region        = var.region
  instance_name = "firemonitoring-dev-db"
  tier          = "db-f1-micro"

  # Only creating the dev database since this is the dev environment!
  database_names = ["firemonitoring_dev"]

  gke_service_account_email = google_service_account.db_client.email
}

# ── Allow GKE Pods to impersonate the DB Client
resource "google_service_account_iam_binding" "db_client_workload_identity" {
  service_account_id = google_service_account.db_client.name
  role               = "roles/iam.workloadIdentityUser"

  # Allowing both the API pod and the Flyway job to use this identity!
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[fire-monitoring-dev/api-sa]",
    "serviceAccount:${var.project_id}.svc.id.goog[fire-monitoring-dev/flyway-sa]"
  ]
}

# ── Cloud Router & NAT (Allows private GKE nodes to pull public Docker images)
resource "google_compute_router" "router" {
  project = var.project_id
  name    = "router-firemonitoring-dev"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "nat-firemonitoring-dev"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
