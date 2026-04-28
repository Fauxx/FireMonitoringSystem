terraform {
  required_version = ">= 1.5.0"

  backend "s3" {}

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.40.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

data "digitalocean_kubernetes_versions" "this" {}

locals {
  environment           = "prod"
  github_environment    = "production"
  namespace             = "fire-monitoring-prod"
  manage_github_secrets = length(trimspace(var.github_token)) > 0 && length(trimspace(var.github_repo)) > 0
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = digitalocean_kubernetes_cluster.this.name
    clusters = [
      {
        name = digitalocean_kubernetes_cluster.this.name
        cluster = {
          server                   = digitalocean_kubernetes_cluster.this.endpoint
          certificate-authority-data = digitalocean_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
        }
      }
    ]
    contexts = [
      {
        name = digitalocean_kubernetes_cluster.this.name
        context = {
          cluster = digitalocean_kubernetes_cluster.this.name
          user    = digitalocean_kubernetes_cluster.this.name
        }
      }
    ]
    users = [
      {
        name = digitalocean_kubernetes_cluster.this.name
        user = {
          token = digitalocean_kubernetes_cluster.this.kube_config[0].token
        }
      }
    ]
  })
  ghcr_dockerconfigjson = jsonencode({
    auths = {
      "ghcr.io" = {
        auth     = base64encode("${var.ghcr_deploy_username}:${var.ghcr_deploy_token}")
        username = var.ghcr_deploy_username
        password = var.ghcr_deploy_token
      }
    }
  })
}

resource "digitalocean_kubernetes_cluster" "this" {
  name    = "fire-monitoring-${local.environment}"
  region  = var.region
  version = var.doks_version != "" ? var.doks_version : data.digitalocean_kubernetes_versions.this.latest_version

  node_pool {
    name       = "default-pool"
    size       = var.doks_node_size
    node_count = var.doks_node_count
    tags       = ["fire-monitoring", "iot", local.environment]
  }
}

provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.this.endpoint
  token                  = digitalocean_kubernetes_cluster.this.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_secret" "app_secrets" {
  metadata {
    name      = "fire-monitoring-secrets"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    POSTGRES_PASSWORD = var.postgres_password
    DATABASE_URL      = var.database_url
    FLYWAY_PASSWORD   = var.postgres_password
    INFLUXDB_PASSWORD = var.influxdb_password
    INFLUXDB_TOKEN    = var.influxdb_token
    INFLUX_TOKEN      = var.influxdb_token
  }

  type = "Opaque"
}

resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "fire-monitoring-config"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    POSTGRES_USER          = var.postgres_user
    POSTGRES_DB            = var.postgres_db
    POSTGRES_HOST          = var.postgres_host
    POSTGRES_PORT          = tostring(var.postgres_port)
    PGSSLMODE              = var.pgsslmode
    FLYWAY_URL             = "jdbc:postgresql://${var.postgres_host}:${var.postgres_port}/${var.postgres_db}"
    FLYWAY_USER            = var.postgres_user
    INFLUXDB_INIT_MODE     = var.influxdb_init_mode
    INFLUXDB_USERNAME      = var.influxdb_username
    INFLUXDB_URL           = var.influxdb_url
    INFLUXDB_ORG           = var.influxdb_org
    INFLUXDB_BUCKET        = var.influxdb_bucket
    INFLUXDB_CLI_CONFIG_NAME = var.influxdb_cli_config_name
    INFLUX_MEASUREMENT     = var.influx_measurement
    MQTT_BROKER_HOST       = var.mqtt_broker_host
    MQTT_BROKER_PORT       = tostring(var.mqtt_broker_port)
    ETL_SYNC_INTERVAL      = tostring(var.etl_sync_interval)
    AGG_WINDOW_MINUTES     = tostring(var.agg_window_minutes)
    THRESHOLD_SMOKE_ORANGE = tostring(var.threshold_smoke_orange)
    THRESHOLD_SMOKE_RED    = tostring(var.threshold_smoke_red)
    THRESHOLD_TEMP_ORANGE  = tostring(var.threshold_temp_orange)
    THRESHOLD_TEMP_RED     = tostring(var.threshold_temp_red)
  }
}

resource "kubernetes_secret" "ghcr_credentials" {
  metadata {
    name      = "ghcr-credentials"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = local.ghcr_dockerconfigjson
  }

  type = "kubernetes.io/dockerconfigjson"
}

module "github_secrets" {
  source                  = "../../modules/github-secrets"
  enabled                 = local.manage_github_secrets
  github_repo             = var.github_repo
  github_environment      = local.github_environment
  do_ssh_host             = ""
  do_ssh_host_fingerprint = ""
  do_ssh_port             = ""
  do_ssh_user             = ""
  do_ssh_private_key      = ""
  kubeconfig              = local.kubeconfig
  ghcr_deploy_username    = var.ghcr_deploy_username
  ghcr_deploy_token       = var.ghcr_deploy_token
}

