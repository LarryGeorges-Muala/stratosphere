###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### helm package ./nginx --destination ./nginx/charts
### helm lint --strict ./nginx/charts/nginx-0.1.0.tgz
### helm template ./nginx/charts/nginx-0.1.0.tgz --values ./nginx/values.yaml
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
# Data - Security Groups
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group
################################################################################

data "aws_security_group" "loadbalancer" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_loadbalancer"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

################################################################################
# Data - Target Groups
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_target_group
################################################################################

data "aws_lb_target_group" "nginx" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "${each.key}-tg-nginx"
  tags = {
    "elbv2.k8s.aws/cluster" = "${each.key}-vpc"
  }
}

################################################################################
# Helm Releases
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release.html
################################################################################

resource "helm_release" "nginx" {

  provider = helm.cluster_one

  name = "nginx"

  chart = "../../devops/charts/nginx/charts/nginx-0.1.0.tgz"

  namespace = "staging"

  create_namespace = true

  version = "0.1.0"

  cleanup_on_fail = true

  upgrade_install = true

  atomic = true

  reuse_values = true

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
      name  = "serviceAccount.create"
      value = true
    },
    {
      name  = "serviceAccount.name"
      value = "pod-service-account"
    },
    {
      name  = "service.port"
      value = 80
    },
    {
      name  = "service.scheme"
      value = "internal"
    },
    {
      name  = "service.type"
      value = "ClusterIP"
    },
    {
      name  = "targetGroupBinding.enabled"
      value = true
    },
    {
      name  = "targetGroupBinding.arn"
      value = "${data.aws_lb_target_group.nginx[local.main_region].arn}"
    },
    {
      name  = "targetGroupBinding.securityGroup"
      value = "${data.aws_security_group.loadbalancer[local.main_region].id}"
    },
    {
      name  = "ingress.enabled"
      value = false
    },
    {
      name  = "namespace"
      value = "staging"
    }
  ]
}

resource "helm_release" "nginx_disaster_recovery" {

  count = var.disaster_recovery_enabled ? 1 : 0

  provider = helm.cluster_two

  name = "nginx"

  chart = "../../devops/charts/nginx/charts/nginx-0.1.0.tgz"

  namespace = "staging"

  create_namespace = true

  version = "0.1.0"

  cleanup_on_fail = true

  upgrade_install = true

  atomic = true

  reuse_values = true

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
      name  = "serviceAccount.create"
      value = true
    },
    {
      name  = "serviceAccount.name"
      value = "pod-service-account"
    },
    {
      name  = "service.port"
      value = 80
    },
    {
      name  = "service.scheme"
      value = "internal"
    },
    {
      name  = "service.type"
      value = "ClusterIP"
    },
    {
      name  = "targetGroupBinding.enabled"
      value = true
    },
    {
      name  = "targetGroupBinding.arn"
      value = "${data.aws_lb_target_group.nginx[local.recovery_region].arn}"
    },
    {
      name  = "targetGroupBinding.securityGroup"
      value = "${data.aws_security_group.loadbalancer[local.recovery_region].id}"
    },
    {
      name  = "ingress.enabled"
      value = false
    },
    {
      name  = "namespace"
      value = "staging"
    }
  ]
}
