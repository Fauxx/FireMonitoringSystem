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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
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
  environment            = "prod"
  github_environment     = "production"
  namespace              = "fire-monitoring-prod"
  argocd_namespace       = "argocd"
  manage_github_secrets  = length(trimspace(var.github_token)) > 0 && length(trimspace(var.github_repo)) > 0
  argocd_repo_url        = "https://github.com/${var.github_owner}/${var.github_repo}.git"
  argocd_server_internal = "argocd-server.${local.argocd_namespace}.svc.cluster.local"
  image_registry         = length(trimspace(var.github_owner)) > 0 && length(trimspace(var.github_repo)) > 0 ? "ghcr.io/${lower(var.github_owner)}/${lower(var.github_repo)}" : "ghcr.io/your-org/fire-monitoring-system"
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = digitalocean_kubernetes_cluster.this.name
    clusters = [
      {
        name = digitalocean_kubernetes_cluster.this.name
        cluster = {
          server                     = digitalocean_kubernetes_cluster.this.endpoint
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

provider "helm" {
  kubernetes {
    host                   = digitalocean_kubernetes_cluster.this.endpoint
    token                  = digitalocean_kubernetes_cluster.this.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
  }
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = local.argocd_namespace
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
    POSTGRES_USER            = var.postgres_user
    POSTGRES_DB              = var.postgres_db
    POSTGRES_HOST            = var.postgres_host
    POSTGRES_PORT            = tostring(var.postgres_port)
    PGSSLMODE                = var.pgsslmode
    FLYWAY_URL               = "jdbc:postgresql://${var.postgres_host}:${var.postgres_port}/${var.postgres_db}"
    FLYWAY_USER              = var.postgres_user
    INFLUXDB_INIT_MODE       = var.influxdb_init_mode
    INFLUXDB_USERNAME        = var.influxdb_username
    INFLUXDB_URL             = var.influxdb_url
    INFLUXDB_ORG             = var.influxdb_org
    INFLUXDB_BUCKET          = var.influxdb_bucket
    INFLUXDB_CLI_CONFIG_NAME = var.influxdb_cli_config_name
    INFLUX_MEASUREMENT       = var.influx_measurement
    MQTT_BROKER_HOST         = var.mqtt_broker_host
    MQTT_BROKER_PORT         = tostring(var.mqtt_broker_port)
    ETL_SYNC_INTERVAL        = tostring(var.etl_sync_interval)
    AGG_WINDOW_MINUTES       = tostring(var.agg_window_minutes)
    THRESHOLD_SMOKE_ORANGE   = tostring(var.threshold_smoke_orange)
    THRESHOLD_SMOKE_RED      = tostring(var.threshold_smoke_red)
    THRESHOLD_TEMP_ORANGE    = tostring(var.threshold_temp_orange)
    THRESHOLD_TEMP_RED       = tostring(var.threshold_temp_red)
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

resource "kubernetes_secret" "argocd_repo_credentials" {
  count = local.manage_github_secrets ? 1 : 0

  metadata {
    name      = "fire-monitoring-repo"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    url      = local.argocd_repo_url
    username = "x-access-token"
    password = var.github_token
  }

  type = "Opaque"
}

resource "kubernetes_secret" "argocd_image_updater_registry" {
  metadata {
    name      = "argocd-image-updater-registry"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    username = var.ghcr_deploy_username
    password = var.ghcr_deploy_token
  }

  type = "Opaque"
}

resource "kubernetes_secret" "argocd_image_updater_token" {
  metadata {
    name      = "argocd-image-updater-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    "argocd.token" = var.argocd_auth_token
  }

  type = "Opaque"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

resource "helm_release" "argocd_image_updater" {
  name             = "argocd-image-updater"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-image-updater"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      config = {
        argocd = {
          serverAddress = local.argocd_server_internal
          insecure      = true
          plaintext     = true
          token         = "$ARGOCD_TOKEN"
        }
        registries = [
          {
            name        = "ghcr"
            api_url     = "https://ghcr.io"
            prefix      = "ghcr.io"
            credentials = "secret:argocd-image-updater-registry#username:password"
          }
        ]
      }
      extraEnv = [
        {
          name = "ARGOCD_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret.argocd_image_updater_token.metadata[0].name
              key  = "argocd.token"
            }
          }
        }
      ]
    })
  ]

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.argocd_image_updater_registry,
    kubernetes_secret.argocd_image_updater_token
  ]
}

resource "kubernetes_manifest" "argocd_application" {
  count = local.manage_github_secrets ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "fire-monitoring-prod"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      annotations = {
        "argocd-image-updater.argoproj.io/image-list"                    = "api=${local.image_registry}/api,etl-processor=${local.image_registry}/etl-processor,dashboard=${local.image_registry}/dashboard"
        "argocd-image-updater.argoproj.io/write-back-method"             = "argocd"
        "argocd-image-updater.argoproj.io/api.kustomize-image"           = "api"
        "argocd-image-updater.argoproj.io/api.update-strategy"           = "newest-build"
        "argocd-image-updater.argoproj.io/api.allow-tags"                = "regexp:^sha-[0-9a-f]{12}$"
        "argocd-image-updater.argoproj.io/etl-processor.kustomize-image" = "etl-processor"
        "argocd-image-updater.argoproj.io/etl-processor.update-strategy" = "newest-build"
        "argocd-image-updater.argoproj.io/etl-processor.allow-tags"      = "regexp:^sha-[0-9a-f]{12}$"
        "argocd-image-updater.argoproj.io/dashboard.kustomize-image"     = "dashboard"
        "argocd-image-updater.argoproj.io/dashboard.update-strategy"     = "newest-build"
        "argocd-image-updater.argoproj.io/dashboard.allow-tags"          = "regexp:^sha-[0-9a-f]{12}$"
      }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = local.argocd_repo_url
        targetRevision = "main"
        path           = "infrastructure/k8s/overlays/prod"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = local.namespace
      }
    }
  }

  depends_on = [helm_release.argocd]
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
  argocd_server           = var.argocd_server
  argocd_auth_token       = var.argocd_auth_token
}

