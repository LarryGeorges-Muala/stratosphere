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
# Kubernetes Secrets
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret.html
################################################################################

resource "kubernetes_secret" "nginx_custom_config" {
  provider = kubernetes.cluster_one
  metadata {
    name      = "nginx-custom-config"
    namespace = "staging"
  }
  data = {
    "custom.conf" = "${file("../charts/nginx/custom_nginx.conf")}"
  }
  type = "generic"
}

resource "kubernetes_secret" "nginx_custom_config_disaster_recovery" {
  count    = var.disaster_recovery_enabled ? 1 : 0
  provider = kubernetes.cluster_two
  metadata {
    name      = "nginx-custom-config"
    namespace = "staging"
  }
  data = {
    "custom.conf" = "${file("../charts/nginx/custom_nginx.conf")}"
  }
  type = "generic"
}

resource "kubernetes_secret" "nginx_custom_template" {
  depends_on = [
    kubernetes_secret.nginx_custom_config
  ]
  provider = kubernetes.cluster_one
  metadata {
    name      = "nginx-custom-template"
    namespace = "staging"
  }
  data = {
    "index.html" = "${file("../charts/nginx/custom_index.html")}"
  }
  type = "generic"
}

resource "kubernetes_secret" "nginx_custom_template_disaster_recovery" {
  depends_on = [
    kubernetes_secret.nginx_custom_config_disaster_recovery
  ]
  count    = var.disaster_recovery_enabled ? 1 : 0
  provider = kubernetes.cluster_two
  metadata {
    name      = "nginx-custom-template"
    namespace = "staging"
  }
  data = {
    "index.html" = "${file("../charts/nginx/custom_index.html")}"
  }
  type = "generic"
}
