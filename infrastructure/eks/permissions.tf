################################################################################
# Data - Caller Identity
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
################################################################################

## Local Identity
data "aws_caller_identity" "current" {}

################################################################################
# Data - Policy Document
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
################################################################################

## Load Balancer Controller
data "aws_iam_policy_document" "load_balancer_controller" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
  }
}

################################################################################
# Roles
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
################################################################################

## Cluster Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "${local.region}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

## Node Role
resource "aws_iam_role" "eks_node_role" {
  depends_on = [
    aws_iam_role.eks_cluster_role
  ]
  name = "${local.region}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

## Addon Role
resource "aws_iam_role" "eks_addon_role" {
  depends_on = [
    aws_iam_role.eks_node_role
  ]
  name = "${local.region}-eks-addon-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      },
    ]
  })
}

## Cluster Admin Role
resource "aws_iam_role" "eks_admin" {
  depends_on = [
    aws_iam_role.eks_addon_role
  ]
  name = "${local.region}-eks-admin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole"
        ]
        Effect = "Allow"
        Principal = {
          "AWS" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      },
    ]
  })
}

## Autoscaler Role
resource "aws_iam_role" "cluster_autoscaler" {
  depends_on = [
    aws_iam_role.eks_admin
  ]
  name = "${local.region}-cluster-autoscaler"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      },
    ]
  })
}

## Load Balancer Controller Role
resource "aws_iam_role" "load_balancer_controller" {
  depends_on = [
    aws_iam_role.cluster_autoscaler
  ]
  name               = "${local.region}-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller.json
}

## Pod Role
resource "aws_iam_role" "iam_pod" {
  depends_on = [
    aws_iam_role.load_balancer_controller
  ]

  name = "${local.region}-iam-pod"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowEksAuthToAssumeRoleForPodIdentity",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "pods.eks.amazonaws.com"
        },
        "Action" : [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}


################################################################################
# Users
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user
################################################################################

## EKS Developer
resource "aws_iam_user" "developer" {
  depends_on = [
    aws_iam_role.load_balancer_controller
  ]
  name = "developer"
}

## EKS Admin
resource "aws_iam_user" "manager" {
  depends_on = [
    aws_iam_user.developer
  ]
  name = "manager"
}

################################################################################
# Policies
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
################################################################################

## EKS Developer
resource "aws_iam_policy" "developer_eks" {
  depends_on = [
    aws_iam_user.manager
  ]
  name = "amazonEKSDeveloperPolicy"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

## EKS Admin
resource "aws_iam_policy" "eks_admin" {
  depends_on = [
    aws_iam_policy.developer_eks
  ]
  name = "amazonEKSAdminPolicy"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "iam:PassRole"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          "StringEquals" = {
            "iam:PassedToService" = "eks.amazonaws.com"
          }
        }
      },
    ]
  })
}

resource "aws_iam_policy" "eks_assume_admin" {
  depends_on = [
    aws_iam_policy.eks_admin
  ]
  name = "amazonEKSAssumeAdminPolicy"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole"
        ]
        Effect   = "Allow"
        Resource = "${aws_iam_role.eks_admin.arn}"
      },
    ]
  })
}

## Autoscaler
resource "aws_iam_policy" "cluster_autoscaler" {
  depends_on = [
    aws_iam_policy.eks_assume_admin
  ]
  name = "${local.region}-cluster-autoscaler"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodeGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceAutoScalingGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

## Load Balancer Controller
resource "aws_iam_policy" "load_balancer_controller" {
  depends_on = [
    aws_iam_policy.cluster_autoscaler
  ]
  name   = "AWSLoadBalancerController"
  policy = file("./iam/AWSLoadBalancerController.json")
}


## Pod
resource "aws_iam_policy" "iam_pod" {
  depends_on = [
    aws_iam_policy.load_balancer_controller
  ]

  name = "${local.region}-iam-pod"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "iam:PassedToService" : "pods.eks.amazonaws.com"
          }
        }
      },
      {
        Action = [
          "ec2:Describe*",
          "ec2:Search*",
          "ec2:Get*",
          "s3:List*",
          "iam:ListInstanceProfiles"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

################################################################################
# Users Policies Attachments
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment
################################################################################

## EKS Developer
resource "aws_iam_user_policy_attachment" "developer_eks" {
  depends_on = [
    aws_iam_policy.developer_eks,
    aws_iam_user.developer
  ]
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.developer_eks.arn
}

## EKS Admin
resource "aws_iam_user_policy_attachment" "manager" {
  depends_on = [
    aws_iam_policy.eks_assume_admin,
    aws_iam_user.manager
  ]
  user       = aws_iam_user.manager.name
  policy_arn = aws_iam_policy.eks_assume_admin.arn
}

################################################################################
# Roles Policy Attachment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
################################################################################

## Cluster Role Permissions
resource "aws_iam_role_policy_attachment" "eks_cluster_role_AmazonEKSClusterPolicy" {
  depends_on = [
    aws_iam_role.eks_cluster_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_AmazonEKSComputePolicy" {
  depends_on = [
    aws_iam_role.eks_cluster_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_AmazonEKSBlockStoragePolicy" {
  depends_on = [
    aws_iam_role.eks_cluster_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_AmazonEKSLoadBalancingPolicy" {
  depends_on = [
    aws_iam_role.eks_cluster_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_AmazonEKSNetworkingPolicy" {
  depends_on = [
    aws_iam_role.eks_cluster_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

## Node Role Permissions
resource "aws_iam_role_policy_attachment" "eks_node_role_AmazonEKSWorkerNodePolicy" {
  depends_on = [
    aws_iam_role.eks_node_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}
resource "aws_iam_role_policy_attachment" "eks_node_role_AmazonEC2ContainerRegistryPullOnly" {
  depends_on = [
    aws_iam_role.eks_node_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.eks_node_role.name
}
resource "aws_iam_role_policy_attachment" "eks_node_role_AmazonEKS_CNI_Policy" {
  depends_on = [
    aws_iam_role.eks_node_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}
resource "aws_iam_role_policy_attachment" "eks_node_role_AmazonEC2ContainerRegistryReadOnly" {
  depends_on = [
    aws_iam_role.eks_node_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}
## TEST
# resource "aws_iam_role_policy_attachment" "eks_node_role_AmazonEC2ContainerRegistryFullAccess" {
#   depends_on = [
#     aws_iam_role.eks_node_role
#   ]
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
#   role       = aws_iam_role.eks_node_role.name
# }

## Addon Role Permissions
resource "aws_iam_role_policy_attachment" "eks_addon_role_AmazonEKSClusterPolicy" {
  depends_on = [
    aws_iam_role.eks_addon_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_addon_role.name
}
resource "aws_iam_role_policy_attachment" "eks_addon_role_AmazonEKSComputePolicy" {
  depends_on = [
    aws_iam_role.eks_addon_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.eks_addon_role.name
}
resource "aws_iam_role_policy_attachment" "eks_addon_role_AmazonEKSBlockStoragePolicy" {
  depends_on = [
    aws_iam_role.eks_addon_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.eks_addon_role.name
}
resource "aws_iam_role_policy_attachment" "eks_addon_role_AmazonEKSLoadBalancingPolicy" {
  depends_on = [
    aws_iam_role.eks_addon_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.eks_addon_role.name
}
resource "aws_iam_role_policy_attachment" "eks_addon_role_AmazonEKSNetworkingPolicy" {
  depends_on = [
    aws_iam_role.eks_addon_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.eks_addon_role.name
}
resource "aws_iam_role_policy_attachment" "eks_addon_role_AmazonEKSWorkerNodePolicy" {
  depends_on = [
    aws_iam_role.eks_addon_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_addon_role.name
}
resource "aws_iam_role_policy_attachment" "eks_addon_role_AmazonEKS_CNI_Policy" {
  depends_on = [
    aws_iam_role.eks_addon_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_addon_role.name
}
resource "aws_iam_role_policy_attachment" "eks_addon_role_AmazonEKSVPCResourceController" {
  depends_on = [
    aws_iam_role.eks_addon_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_addon_role.name
}
resource "aws_iam_role_policy_attachment" "eks_addon_role_AmazonEKSServicePolicy" {
  depends_on = [
    aws_iam_role.eks_addon_role
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_addon_role.name
}

## EKS Admin Role Permissions
resource "aws_iam_role_policy_attachment" "eks_admin" {
  depends_on = [
    aws_iam_role.eks_admin,
    aws_iam_policy.eks_admin
  ]
  role       = aws_iam_role.eks_admin.name
  policy_arn = aws_iam_policy.eks_admin.arn
}

## Autoscaler Role Permissions
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  depends_on = [
    aws_iam_role.cluster_autoscaler,
    aws_iam_policy.cluster_autoscaler
  ]
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_node_role" {
  depends_on = [
    aws_iam_role.eks_addon_role,
    aws_iam_policy.cluster_autoscaler
  ]
  role       = aws_iam_role.eks_addon_role.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

## Load Balancer Controller
resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  depends_on = [
    aws_iam_role.load_balancer_controller,
    aws_iam_policy.load_balancer_controller
  ]
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

## Pod
resource "aws_iam_role_policy_attachment" "iam_pod" {
  depends_on = [
    aws_iam_role.iam_pod,
    aws_iam_policy.iam_pod
  ]
  role       = aws_iam_role.iam_pod.name
  policy_arn = aws_iam_policy.iam_pod.arn
}

################################################################################
# EKS Pod ID Association
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association
################################################################################

## Autoscaler
resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  depends_on = [
    aws_eks_node_group.eks_node_group,
    aws_iam_role.cluster_autoscaler
  ]
  for_each        = tomap(local.disaster_recovery)
  region          = each.key
  cluster_name    = aws_eks_cluster.eks[each.key].name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = aws_iam_role.cluster_autoscaler.arn
}

## Load Balancer Controller
resource "aws_eks_pod_identity_association" "load_balancer_controller" {
  depends_on = [
    aws_eks_pod_identity_association.cluster_autoscaler,
    aws_iam_role.load_balancer_controller
  ]
  for_each        = tomap(local.disaster_recovery)
  region          = each.key
  cluster_name    = aws_eks_cluster.eks[each.key].name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.load_balancer_controller.arn
}

## Pod
resource "aws_eks_pod_identity_association" "iam_pod_build_agents" {
  depends_on = [
    aws_eks_pod_identity_association.load_balancer_controller,
    aws_iam_role.iam_pod
  ]
  for_each        = tomap(local.disaster_recovery)
  region          = each.key
  cluster_name    = aws_eks_cluster.eks[each.key].name
  namespace       = "devops"
  service_account = "build-agent-service-account"
  role_arn        = aws_iam_role.iam_pod.arn
}

resource "aws_eks_pod_identity_association" "iam_pod_game_2048" {
  depends_on = [
    aws_eks_pod_identity_association.iam_pod_build_agents,
    aws_iam_role.iam_pod
  ]
  for_each        = tomap(local.disaster_recovery)
  region          = each.key
  cluster_name    = data.aws_eks_cluster.eks[each.key].name
  namespace       = "staging"
  service_account = "game-2048-service-account"
  role_arn        = aws_iam_role.iam_pod.arn
}

resource "aws_eks_pod_identity_association" "pod_service_account" {
  depends_on = [
    aws_eks_pod_identity_association.iam_pod_game_2048,
    aws_iam_role.iam_pod
  ]
  for_each        = tomap(local.disaster_recovery)
  region          = each.key
  cluster_name    = data.aws_eks_cluster.eks[each.key].name
  namespace       = "staging"
  service_account = "pod-service-account"
  role_arn        = aws_iam_role.iam_pod.arn
}

################################################################################
# Access Entries
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry
################################################################################

## EKS RBAC Attachments - Admin
resource "aws_eks_access_entry" "manager" {
  depends_on = [
    kubectl_manifest.viewer_cluster_role_binding,
    aws_iam_role.eks_admin
  ]
  for_each          = tomap(local.disaster_recovery)
  region            = each.key
  cluster_name      = aws_eks_cluster.eks[each.key].name
  principal_arn     = aws_iam_role.eks_admin.arn
  kubernetes_groups = ["admin-group"]
  type              = "STANDARD"
}

## EKS RBAC Attachments - Developer
resource "aws_eks_access_entry" "developer" {
  depends_on = [
    aws_eks_access_entry.manager,
    aws_iam_user.developer
  ]
  for_each          = tomap(local.disaster_recovery)
  region            = each.key
  cluster_name      = aws_eks_cluster.eks[each.key].name
  principal_arn     = aws_iam_user.developer.arn
  kubernetes_groups = ["viewer-group"]
  type              = "STANDARD"
}
