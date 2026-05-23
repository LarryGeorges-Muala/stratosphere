###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
###############################################################################

################################################################################
# Locals
################################################################################

locals {
  main_region     = "ap-southeast-1"
  recovery_region = "eu-west-1"

  region = local.main_region

  main_region_setup = {
    "${local.main_region}" = []
  }

  main_and_recovery_region_setup = {
    "${local.main_region}"     = []
    "${local.recovery_region}" = []
  }

  disaster_recovery = var.disaster_recovery_enabled == true ? local.main_and_recovery_region_setup : local.main_region_setup

  disaster_recovery_status = var.disaster_recovery_enabled == true ? "multi-region setup active" : "single-region setup active"

  tags = {
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# Data - GCloud
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
################################################################################

data "google_client_config" "provider" {}

################################################################################
# Data - Current GKE Cluster
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/container_cluster
################################################################################

data "google_container_cluster" "gke" {
  for_each = tomap(local.disaster_recovery)
  name     = "${each.key}-gke"
  location = each.key
}

################################################################################
# Helm Releases
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release.html
################################################################################

## ArgoCD - Main
resource "helm_release" "argo_cd" {

  provider = helm.cluster_one

  name = "argocd"

  repository = "https://argoproj.github.io/argo-helm"

  chart = "argo-cd"

  namespace = "argocd"

  create_namespace = true

  version = "3.55.4"

  cleanup_on_fail = true

  upgrade_install = true

  atomic = true

  lint = false

  values = [file("${path.module}/helm-values/argocd.yaml")]
}

## ArgoCD - Recovery
resource "helm_release" "argo_cd_disaster_recovery" {

  provider = helm.cluster_two

  count = var.disaster_recovery_enabled ? 1 : 0

  name = "argocd"

  repository = "https://argoproj.github.io/argo-helm"

  chart = "argo-cd"

  namespace = "argocd"

  create_namespace = true

  version = "3.55.4"

  cleanup_on_fail = true

  upgrade_install = true

  atomic = true

  lint = false

  values = [file("${path.module}/helm-values/argocd.yaml")]
}
