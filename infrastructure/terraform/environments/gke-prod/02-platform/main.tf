data "google_client_config" "default" {}

data "terraform_remote_state" "infra" {
  backend = "gcs"
  config = {
    bucket = "firemonitoring-tfstate"
    prefix = "gke-prod/01-infra"
  }
}

provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.infra.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_cert)
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.terraform_remote_state.infra.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_cert)
    token                  = data.google_client_config.default.access_token
  }
}

module "ingress_controller" {
  source        = "../../../modules/shared/ingress-controller"
  chart_version = "4.12.0"
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.17.0"
  namespace        = "cert-manager"
  create_namespace = true
  set {
    name  = "crds.enabled"
    value = "true"
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.10.0"
  namespace        = "external-secrets"
  create_namespace = true
}

resource "kubernetes_manifest" "cluster_secret_store" {
  depends_on = [helm_release.external_secrets]
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata   = { name = "gcp-secret-manager" }
    spec = {
      provider = {
        gcpsm = { projectID = data.terraform_remote_state.infra.outputs.project_id }
      }
    }
  }
}
