resource "google_container_cluster" "main" {
  provider = google
  name     = var.cluster_name
  location = var.zone
  project  = var.project_id

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_id
  subnetwork = var.subnet_id

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # GKE Workload Identity (replaces AKS oidc_issuer_enabled + workload_identity_enabled)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # GKE Dataplane V2 (replaces Azure CNI + Calico network policy)
  datapath_provider = "ADVANCED_DATAPATH"

  # Private nodes, public endpoint (matches AKS local_account_disabled pattern)
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.32/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "all — restrict in prod"
    }
  }

  # Weekly maintenance window (Sunday 02:00–06:00, mirrors AKS config)
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T02:00:00Z"
      end_time   = "2024-01-01T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
}

resource "google_container_node_pool" "main" {
  name     = "agentpool"
  cluster  = google_container_cluster.main.id
  location = var.zone
  project  = var.project_id

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = "pd-ssd"
    service_account = var.node_sa_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA" # Required for Workload Identity on pods
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
