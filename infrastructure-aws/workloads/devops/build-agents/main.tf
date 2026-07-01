###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### helm package ./build-agents --destination ./build-agents/charts
### helm lint --strict ./build-agents/charts/build-agents-0.1.0.tgz
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

resource "helm_release" "build_agents" {

  provider = helm.cluster_one

  name = "build-agent"

  chart = "../../devops/charts/build-agents/charts/build-agents-0.1.1.tgz"

  namespace = "devops"

  create_namespace = true

  version = "0.1.1"

  cleanup_on_fail = true

  reuse_values = true

  upgrade_install = true

  atomic = true

  lint = true

  recreate_pods = true

  set = [
    {
      name  = "replicaCount"
      value = data.aws_eks_node_group.eks_node_group[local.main_region].scaling_config[0].min_size
    },
    {
      name  = "autoscaling.minReplicas"
      value = data.aws_eks_node_group.eks_node_group[local.main_region].scaling_config[0].min_size
    },
    {
      name  = "autoscaling.maxReplicas"
      value = data.aws_eks_node_group.eks_node_group[local.main_region].scaling_config[0].max_size
    },
    {
      name  = "autoscaling.targetCPUUtilizationPercentage"
      value = 200
    },
    {
      name  = "autoscaling.targetMemoryUtilizationPercentage"
      value = 200
    },
    {
      name  = "namespace"
      value = "devops"
    }
  ]
}

resource "helm_release" "build_agents_disaster_recovery" {

  count = var.disaster_recovery_enabled ? 1 : 0

  provider = helm.cluster_two

  name = "build-agent"

  chart = "../charts/build-agents/charts/build-agents-0.1.1.tgz"

  namespace = "devops"

  create_namespace = true

  version = "0.1.1"

  cleanup_on_fail = true

  reuse_values = true

  upgrade_install = true

  atomic = true

  lint = true

  recreate_pods = true

  set = [
    {
      name  = "replicaCount"
      value = data.aws_eks_node_group.eks_node_group[local.recovery_region].scaling_config[0].min_size
    },
    {
      name  = "autoscaling.minReplicas"
      value = data.aws_eks_node_group.eks_node_group[local.recovery_region].scaling_config[0].min_size
    },
    {
      name  = "autoscaling.maxReplicas"
      value = data.aws_eks_node_group.eks_node_group[local.recovery_region].scaling_config[0].max_size
    },
    {
      name  = "autoscaling.targetCPUUtilizationPercentage"
      value = 200
    },
    {
      name  = "autoscaling.targetMemoryUtilizationPercentage"
      value = 200
    },
    {
      name  = "namespace"
      value = "devops"
    }
  ]
}
