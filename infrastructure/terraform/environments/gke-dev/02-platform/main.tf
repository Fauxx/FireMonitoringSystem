data "google_client_config" "default" {}

data "terraform_remote_state" "infra" {
  backend = "gcs"
  config = {
    bucket = "firemonitoring-tfstate"
    prefix = "gke-dev/01-infra"
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

