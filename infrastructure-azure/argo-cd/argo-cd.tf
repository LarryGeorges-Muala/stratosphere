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
  main_region     = "southeastasia"
  recovery_region = "westeurope"

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
# Data - Resource Group
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group
################################################################################

data "azurerm_resource_group" "asia" {
  name = local.main_region
}

data "azurerm_resource_group" "europe" {
  name = local.recovery_region
}

################################################################################
# Data - Azure
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config
################################################################################

data "azurerm_client_config" "current" {}

################################################################################
# Data - Current AKS Cluster
# https://registry.terraform.io/providers/hashicorp/Azurerm/latest/docs/data-sources/kubernetes_cluster
################################################################################

data "azurerm_kubernetes_cluster" "aks" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-aks"
  resource_group_name = each.key
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

  dependency_update = true

  version = "9.5.17"

  cleanup_on_fail = true

  upgrade_install = true

  force_update = false

  recreate_pods = false

  atomic = true

  lint = false
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

  dependency_update = true

  version = "9.5.17"

  cleanup_on_fail = true

  upgrade_install = true

  force_update = false

  recreate_pods = false

  atomic = true

  lint = false
}
