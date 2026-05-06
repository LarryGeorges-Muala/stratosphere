###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
###############################################################################

################################################################################
# VPC Availability Zones
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones
################################################################################

data "aws_availability_zones" "africa" {
  state = "available"

  filter {
    name   = "region-name"
    values = ["af-south-1"]
  }
}

data "aws_availability_zones" "asia" {
  state  = "available"
  region = "ap-southeast-1"
}

data "aws_availability_zones" "europe" {
  state  = "available"
  region = "eu-west-1"
}

################################################################################
# Locals
################################################################################

locals {
  main_region     = "ap-southeast-1"
  recovery_region = "eu-west-1"

  region = local.main_region

  main_availability_zone_ids     = data.aws_availability_zones.asia.zone_ids
  recovery_availability_zone_ids = data.aws_availability_zones.europe.zone_ids

  main_region_setup = {
    "${local.main_region}" = [
      local.main_availability_zone_ids
    ]
  }

  main_and_recovery_region_setup = {
    "${local.main_region}" = [
      local.main_availability_zone_ids
    ]
    "${local.recovery_region}" = [
      local.recovery_availability_zone_ids
    ]
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

  region = each.key

  filter {
    name   = "tag:Name"
    values = ["${each.key}-vpc"]
  }
}

################################################################################
# Data - Subnets
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet
################################################################################

## Privates Subnets
data "aws_subnet" "vpc_private_subnet_1" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][0]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-private-subnet-1"]
  }
}

data "aws_subnet" "vpc_private_subnet_2" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][1]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-private-subnet-2"]
  }
}

data "aws_subnet" "vpc_private_subnet_3" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][2]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-private-subnet-3"]
  }
}

## Public Subnets
data "aws_subnet" "vpc_public_subnet_1" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][0]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-public-subnet-1"]
  }
}

data "aws_subnet" "vpc_public_subnet_2" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][1]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-public-subnet-2"]
  }
}

data "aws_subnet" "vpc_public_subnet_3" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][2]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-public-subnet-3"]
  }
}

################################################################################
# Data - Security Groups
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group
################################################################################

data "aws_security_group" "open" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_open_traffic"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

data "aws_security_group" "ssh" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_ssh"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

data "aws_security_group" "http" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_http"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

data "aws_security_group" "http_debug" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_http_debug"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

data "aws_security_group" "https" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_https"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

################################################################################
# Data - Current EKS Cluster
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster
################################################################################

data "aws_eks_cluster" "eks" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = aws_eks_cluster.eks[each.key].name
}

data "aws_eks_cluster_auth" "eks" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = aws_eks_cluster.eks[each.key].name
}

################################################################################
# EKS
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster
# https://docs.aws.amazon.com/eks/latest/userguide/eks-provisioned-control-plane-getting-started.html
################################################################################

## Cluster
resource "aws_eks_cluster" "eks" {

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_role_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_role_AmazonEKSComputePolicy,
    aws_iam_role_policy_attachment.eks_cluster_role_AmazonEKSBlockStoragePolicy,
    aws_iam_role_policy_attachment.eks_cluster_role_AmazonEKSLoadBalancingPolicy,
    aws_iam_role_policy_attachment.eks_cluster_role_AmazonEKSNetworkingPolicy,
    aws_iam_role_policy_attachment.eks_node_role_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_role_AmazonEC2ContainerRegistryPullOnly,
    aws_iam_role_policy_attachment.eks_node_role_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_node_role_AmazonEC2ContainerRegistryReadOnly,
    # aws_iam_role_policy_attachment.eks_node_role_AmazonEC2ContainerRegistryFullAccess,
    aws_iam_role_policy_attachment.eks_addon_role_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_addon_role_AmazonEKSComputePolicy,
    aws_iam_role_policy_attachment.eks_addon_role_AmazonEKSBlockStoragePolicy,
    aws_iam_role_policy_attachment.eks_addon_role_AmazonEKSLoadBalancingPolicy,
    aws_iam_role_policy_attachment.eks_addon_role_AmazonEKSNetworkingPolicy,
    aws_iam_role_policy_attachment.eks_addon_role_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_addon_role_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_addon_role_AmazonEKSVPCResourceController,
    aws_iam_role_policy_attachment.eks_addon_role_AmazonEKSServicePolicy,
    aws_iam_role_policy_attachment.eks_admin,
    aws_iam_role_policy_attachment.cluster_autoscaler,
    aws_iam_role_policy_attachment.cluster_autoscaler_node_role,
    aws_iam_role_policy_attachment.load_balancer_controller
  ]

  for_each = tomap(local.disaster_recovery)

  role_arn = aws_iam_role.eks_cluster_role.arn

  region = each.key

  name = "${each.key}-eks"

  version = "1.34"

  access_config {
    # authentication_mode = "API_AND_CONFIG_MAP"
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    # cluster_security_group_id = "sg-0fa42786bf928da89"
    endpoint_private_access = false
    endpoint_public_access  = true

    # public_access_cidrs = [
    #   "0.0.0.0/0"
    # ]
    # security_group_ids = [
    #   "sg-0f25fdd75c0e0e7be"
    # ]
    # security_group_ids = [
    #   data.aws_security_group.ssh.id,
    #   data.aws_security_group.http.id,
    #   data.aws_security_group.https.id,
    #   data.aws_security_group.open.id,
    # ]
    subnet_ids = [
      data.aws_subnet.vpc_private_subnet_1[each.key].id,
      data.aws_subnet.vpc_private_subnet_2[each.key].id,
      data.aws_subnet.vpc_private_subnet_3[each.key].id
    ]
  }

  # compute_config {
  #   enabled = true
  #   node_pools = [
  #     "general-purpose",
  #     "system"
  #   ]
  #   # node_pools    = null
  #   node_role_arn = aws_iam_role.eks_node_role.arn
  # }

  # kubernetes_network_config {
  #   elastic_load_balancing {
  #     enabled = true
  #   }
  #   ip_family         = "ipv4"
  #   # service_ipv4_cidr = "172.16.0.0/12"
  #   # service_ipv4_cidr = local.vpc_cidr_block_1_range_2
  #   service_ipv4_cidr = null
  #   service_ipv6_cidr = null
  # }

  # storage_config {
  #   block_storage {
  #     enabled = true
  #   }
  # }

  # control_plane_scaling_config {
  #   tier = "standard"
  # }

  # bootstrap_self_managed_addons = false

  # deletion_protection = false

  # enabled_cluster_log_types = []

  # force_update_version = null

  # upgrade_policy {
  #   support_type = "STANDARD"
  # }

  # zonal_shift_config {
  #     enabled = false
  # }

  # encryption_config {
  #   provider {
  #     key_arn = ""
  #   }
  #   resources = []
  # }

  # remote_network_config {
  #   remote_node_networks {
  #     cidrs = ["172.16.0.0/18"]
  #   }
  #   remote_pod_networks {
  #     cidrs = ["172.16.64.0/18"]
  #   }
  # }

  # outpost_config {
  #   control_plane_instance_type = "m5.large"
  #   outpost_arns                = [data.aws_outposts_outpost.example.arn]
  # }

  tags = {
    "Name"                     = "${each.key}-eks"
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# EKS Node Group Launch Template
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template
################################################################################
# resource "aws_launch_template" "eks_launch_template" {
#   depends_on = [aws_eks_cluster.eks]

#   name = "${local.region}-eks-node-launch-template"

#   instance_type = "t3.medium"

#   block_device_mappings {
#     device_name = "/dev/sdf"

#     ebs {
#       volume_size = 20
#     }
#   }

#   # vpc_security_group_ids = [
#   #   data.aws_security_group.ssh.id,
#   #   data.aws_security_group.http.id,
#   #   data.aws_security_group.https.id,
#   #   data.aws_security_group.open.id
#   # ]

#   user_data = filebase64("${path.module}/scripts/bootstrap-node-group.sh")

# }

################################################################################
# EKS Node Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group
################################################################################

resource "aws_eks_node_group" "eks_node_group" {
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_eks_addon.eks_pod_identity_agent,
    aws_eks_addon.vpc_cni
    # aws_launch_template.eks_launch_template
  ]

  for_each = tomap(local.disaster_recovery)

  region = each.key

  cluster_name = aws_eks_cluster.eks[each.key].name

  version = aws_eks_cluster.eks[each.key].version

  node_group_name = "${each.key}-eks-node-group"

  node_role_arn = aws_iam_role.eks_node_role.arn

  subnet_ids = [
    data.aws_subnet.vpc_private_subnet_1[each.key].id,
    data.aws_subnet.vpc_private_subnet_2[each.key].id,
    data.aws_subnet.vpc_private_subnet_3[each.key].id
  ]

  scaling_config {
    desired_size = 1
    max_size     = 20
    min_size     = 1
  }

  # remote_access {
  #   source_security_group_ids = [
  #     data.aws_security_group.ssh.id,
  #     data.aws_security_group.http.id,
  #     data.aws_security_group.https.id,
  #     data.aws_security_group.open.id,
  #   ]
  #   ec2_ssh_key = null
  # }

  update_config {
    max_unavailable = 1
    # update_strategy = "DEFAULT"
  }

  # Optional: Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  capacity_type = "ON_DEMAND"

  disk_size = 30

  ## Pod Count - https://github.com/awslabs/amazon-eks-ami/blob/main/templates/shared/runtime/eni-max-pods.txt
  # instance_types = ["t3a.large"]
  instance_types = ["t3a.xlarge"]

  labels = {
    role = "general"
  }

  # launch_template {
  #   name = aws_launch_template.eks_launch_template.name
  #   version = "$Latest"
  # }

}

################################################################################
# EKS AddOns
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
################################################################################

resource "aws_eks_addon" "eks_pod_identity_agent" {
  depends_on = [
    aws_eks_cluster.eks
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = "v1.3.10-eksbuild.2"
  service_account_role_arn    = null
  resolve_conflicts_on_update = "PRESERVE"
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "vpc_cni" {
  depends_on = [
    aws_eks_addon.eks_pod_identity_agent
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.21.1-eksbuild.3"
  resolve_conflicts_on_update = "PRESERVE"
  pod_identity_association {
    role_arn        = aws_iam_role.eks_addon_role.arn
    service_account = "aws-node"
  }
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "core_dns" {
  depends_on = [
    helm_release.load_balancer_controller
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "coredns"
  addon_version               = "v1.13.2-eksbuild.1"
  service_account_role_arn    = null
  resolve_conflicts_on_update = "PRESERVE"
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "kube_proxy" {
  depends_on = [
    aws_eks_addon.core_dns
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.34.3-eksbuild.2"
  service_account_role_arn    = null
  resolve_conflicts_on_update = "PRESERVE"
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "aws_secrets_store_csi_driver_provider" {
  depends_on = [
    aws_eks_addon.kube_proxy
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "aws-secrets-store-csi-driver-provider"
  addon_version               = "v2.1.1-eksbuild.1"
  service_account_role_arn    = null
  resolve_conflicts_on_update = "PRESERVE"
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "eks_node_monitoring_agent" {
  depends_on = [
    aws_eks_addon.aws_secrets_store_csi_driver_provider
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "eks-node-monitoring-agent"
  addon_version               = "v1.5.1-eksbuild.1"
  service_account_role_arn    = null
  resolve_conflicts_on_update = "PRESERVE"
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "aws_network_flow_monitoring_agent" {
  depends_on = [
    aws_eks_addon.eks_node_monitoring_agent
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "aws-network-flow-monitoring-agent"
  addon_version               = "v1.1.3-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  pod_identity_association {
    role_arn        = aws_iam_role.eks_addon_role.arn
    service_account = "aws-network-flow-monitor-agent-service-account"
  }
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "cert_manager" {
  depends_on = [
    aws_eks_addon.aws_network_flow_monitoring_agent
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "cert-manager"
  addon_version               = "v1.19.3-eksbuild.2"
  service_account_role_arn    = null
  resolve_conflicts_on_update = "PRESERVE"
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "aws_privateca_connector_for_kubernetes" {
  depends_on = [
    aws_eks_addon.cert_manager
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "aws-privateca-connector-for-kubernetes"
  addon_version               = "v1.7.1-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  pod_identity_association {
    role_arn        = aws_iam_role.eks_addon_role.arn
    service_account = "aws-privateca-issuer"
  }
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "external_dns" {
  depends_on = [
    aws_eks_addon.aws_privateca_connector_for_kubernetes
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "external-dns"
  addon_version               = "v0.20.0-eksbuild.3"
  resolve_conflicts_on_update = "PRESERVE"
  pod_identity_association {
    role_arn        = aws_iam_role.eks_addon_role.arn
    service_account = "external-dns"
  }
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "amazon_cloudwatch_observability" {
  depends_on = [
    aws_eks_addon.external_dns
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "amazon-cloudwatch-observability"
  addon_version               = "v4.10.1-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  pod_identity_association {
    role_arn        = aws_iam_role.eks_addon_role.arn
    service_account = "cloudwatch-agent"
  }
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "aws_ebs_csi_driver" {
  depends_on = [
    aws_eks_addon.amazon_cloudwatch_observability
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = "v1.55.0-eksbuild.2"
  resolve_conflicts_on_update = "PRESERVE"
  pod_identity_association {
    role_arn        = aws_iam_role.eks_addon_role.arn
    service_account = "ebs-csi-controller-sa"
  }
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "aws_efs_csi_driver" {
  depends_on = [
    aws_eks_addon.aws_ebs_csi_driver
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "aws-efs-csi-driver"
  addon_version               = "v2.3.0-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  pod_identity_association {
    role_arn        = aws_iam_role.eks_addon_role.arn
    service_account = "efs-csi-controller-sa"
  }
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "aws_mountpoint_s3_csi_driver" {
  depends_on = [
    aws_eks_addon.aws_efs_csi_driver
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "aws-mountpoint-s3-csi-driver"
  addon_version               = "v2.3.0-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  pod_identity_association {
    role_arn        = aws_iam_role.eks_addon_role.arn
    service_account = "s3-csi-driver-sa"
  }
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_eks_addon" "fluent_bit" {
  depends_on = [
    aws_eks_addon.aws_mountpoint_s3_csi_driver
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  cluster_name                = aws_eks_cluster.eks[each.key].name
  addon_name                  = "fluent-bit"
  addon_version               = "v4.2.2-eksbuild.2"
  service_account_role_arn    = null
  resolve_conflicts_on_update = "PRESERVE"
  timeouts {
    create = "10m"
    delete = "10m"
  }
  tags = {
    "cluster_name"             = "${each.key}-eks"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# Kubectl YAML Manifest
# https://github.com/gavinbunney/terraform-provider-kubectl
################################################################################

## Main
resource "kubectl_manifest" "viewer_cluster_role" {
  depends_on = [
    aws_eks_pod_identity_association.load_balancer_controller
  ]
  provider  = kubectl.cluster_one
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewer
rules:
  - apiGroups: ["*"]
    resources: ["deployments", "configmaps", "pods", "secrets", "services"]
    verbs: ["get", "list", "watch"]
YAML
}

## Recovery
resource "kubectl_manifest" "viewer_cluster_role_disaster_recovery" {
  depends_on = [
    aws_eks_pod_identity_association.load_balancer_controller
  ]
  provider  = kubectl.cluster_two
  count     = var.disaster_recovery_enabled ? 1 : 0
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewer
rules:
  - apiGroups: ["*"]
    resources: ["deployments", "configmaps", "pods", "secrets", "services"]
    verbs: ["get", "list", "watch"]
YAML
}

## Main
resource "kubectl_manifest" "admin_cluster_role_binding" {
  depends_on = [
    kubectl_manifest.viewer_cluster_role_binding
  ]
  provider  = kubectl.cluster_one
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-group-binding
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: Group
    name: admin-group
    apiGroup: rbac.authorization.k8s.io
YAML
}

## Recovery
resource "kubectl_manifest" "admin_cluster_role_binding_disaster_recovery" {
  depends_on = [
    kubectl_manifest.viewer_cluster_role_binding
  ]
  provider  = kubectl.cluster_two
  count     = var.disaster_recovery_enabled ? 1 : 0
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-group-binding
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: Group
    name: admin-group
    apiGroup: rbac.authorization.k8s.io
YAML
}

## Main
resource "kubectl_manifest" "viewer_cluster_role_binding" {
  depends_on = [
    kubectl_manifest.viewer_cluster_role
  ]
  provider  = kubectl.cluster_one
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewer-group-binding
roleRef:
  kind: ClusterRole
  name: viewer
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: Group
    name: viewer-group
    apiGroup: rbac.authorization.k8s.io
YAML
}

## Recovery
resource "kubectl_manifest" "viewer_cluster_role_binding_disaster_recovery" {
  depends_on = [
    kubectl_manifest.viewer_cluster_role
  ]
  provider  = kubectl.cluster_two
  count     = var.disaster_recovery_enabled ? 1 : 0
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewer-group-binding
roleRef:
  kind: ClusterRole
  name: viewer
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: Group
    name: viewer-group
    apiGroup: rbac.authorization.k8s.io
YAML
}

################################################################################
# Helm Releases
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release.html
################################################################################

## Metrics Server - Main
resource "helm_release" "metrics_server" {
  depends_on = [
    aws_eks_access_entry.developer,
    aws_eks_access_entry.manager
  ]

  provider = helm.cluster_one

  name = "metrics-server"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"

  chart = "metrics-server"

  namespace = "kube-system"

  version = "3.12.1"

  cleanup_on_fail = true

  upgrade_install = true

  atomic = true

  lint = false

  values = [file("${path.module}/helm-values/metrics-server.yaml")]
}

## Metrics Server - Recovery
resource "helm_release" "metrics_server_disaster_recovery" {
  depends_on = [
    aws_eks_access_entry.developer,
    aws_eks_access_entry.manager
  ]

  provider = helm.cluster_two

  count = var.disaster_recovery_enabled ? 1 : 0

  name = "metrics-server"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"

  chart = "metrics-server"

  namespace = "kube-system"

  version = "3.12.1"

  cleanup_on_fail = true

  upgrade_install = true

  atomic = true

  lint = false

  values = [file("${path.module}/helm-values/metrics-server.yaml")]
}

## Autoscaler - Main
resource "helm_release" "cluster_autoscaler" {
  depends_on = [
    helm_release.metrics_server
  ]

  provider = helm.cluster_one

  name = "autoscaler"

  repository = "https://kubernetes.github.io/autoscaler"

  chart = "cluster-autoscaler"

  namespace = "kube-system"

  version = "9.37.0"

  cleanup_on_fail = true

  upgrade_install = true

  atomic = true

  lint = false

  set = [
    {
      name  = "rbac.serviceAccount.name"
      value = "cluster-autoscaler"
    },
    {
      name  = "autoDiscovery.clusterName"
      value = aws_eks_cluster.eks[local.main_region].name
    },
    {
      name  = "awsRegion"
      value = local.region
    }
  ]
}

## Autoscaler - Recovery
resource "helm_release" "cluster_autoscaler_disaster_recovery" {
  depends_on = [
    helm_release.metrics_server
  ]

  provider = helm.cluster_two

  count = var.disaster_recovery_enabled ? 1 : 0

  name = "autoscaler"

  repository = "https://kubernetes.github.io/autoscaler"

  chart = "cluster-autoscaler"

  namespace = "kube-system"

  version = "9.37.0"

  cleanup_on_fail = true

  upgrade_install = true

  atomic = true

  lint = false

  set = [
    {
      name  = "rbac.serviceAccount.name"
      value = "cluster-autoscaler"
    },
    {
      name  = "autoDiscovery.clusterName"
      value = aws_eks_cluster.eks[local.recovery_region].name
    },
    {
      name  = "awsRegion"
      value = local.region
    }
  ]
}

## Load Balancer Controller - Main
resource "helm_release" "load_balancer_controller" {
  depends_on = [
    helm_release.cluster_autoscaler
  ]

  provider = helm.cluster_one

  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"

  chart = "aws-load-balancer-controller"

  namespace = "kube-system"

  version = "1.7.2"

  cleanup_on_fail = true

  upgrade_install = true

  atomic = true

  lint = false

  set = [
    {
      name  = "clusterName"
      value = aws_eks_cluster.eks[local.main_region].name
    },
    {
      name  = "region"
      value = local.region
    },
    {
      name  = "vpcId"
      value = data.aws_vpc.vpc[local.main_region].id
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    }
  ]
}

## Load Balancer Controller - Recovery
resource "helm_release" "load_balancer_controller_disaster_recovery" {
  depends_on = [
    helm_release.cluster_autoscaler
  ]

  provider = helm.cluster_two

  count = var.disaster_recovery_enabled ? 1 : 0

  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"

  chart = "aws-load-balancer-controller"

  namespace = "kube-system"

  version = "1.7.2"

  cleanup_on_fail = true

  upgrade_install = true

  atomic = true

  lint = false

  set = [
    {
      name  = "clusterName"
      value = aws_eks_cluster.eks[local.recovery_region].name
    },
    {
      name  = "region"
      value = local.region
    },
    {
      name  = "vpcId"
      value = data.aws_vpc.vpc[local.recovery_region].id
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    }
  ]
}

################################################################################
# END - EKS
################################################################################
