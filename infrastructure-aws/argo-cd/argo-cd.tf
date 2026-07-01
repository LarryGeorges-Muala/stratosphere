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
# Data - VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc
################################################################################

data "aws_vpc" "vpc" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key

  filter {
    name   = "tag:Name"
    values = ["${each.key}-vpc"]
  }
}

################################################################################
# Data - Current EKS Cluster
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster
################################################################################

data "aws_eks_cluster" "eks" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "${each.key}-eks"
}

################################################################################
# Data - EKS Cluster Auth
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth
################################################################################

data "aws_eks_cluster_auth" "eks" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "${each.key}-eks"
}

################################################################################
# Data - EKS Node Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_node_group
################################################################################

data "aws_eks_node_group" "eks_node_group" {
  for_each        = tomap(local.disaster_recovery)
  region          = each.key
  cluster_name    = "${each.key}-eks"
  node_group_name = "${each.key}-eks-node-group"
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
