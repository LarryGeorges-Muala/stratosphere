terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.36.0"
    }
    # https://github.com/gavinbunney/terraform-provider-kubectl
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.10.0"
    }
    # https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    # https://registry.terraform.io/providers/hashicorp/helm/latest/docs
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
  }

  required_version = "~> 1.6"
}

provider "aws" {
  region  = local.region
  profile = "terraform"
}

provider "helm" {
  alias = "cluster_one"
  kubernetes = {
    host                   = data.aws_eks_cluster.eks[local.main_region].endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks[local.main_region].certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks[local.main_region].token
  }
}

provider "helm" {
  alias = "cluster_two"
  kubernetes = var.disaster_recovery_enabled == true ? {
    host                   = data.aws_eks_cluster.eks[local.recovery_region].endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks[local.recovery_region].certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks[local.recovery_region].token
    } : {
    host                   = data.aws_eks_cluster.eks[local.main_region].endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks[local.main_region].certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks[local.main_region].token
  }
}

provider "kubectl" {
  alias                  = "cluster_one"
  host                   = data.aws_eks_cluster.eks[local.main_region].endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks[local.main_region].certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks[local.main_region].token
  load_config_file       = false
}

provider "kubectl" {
  alias                  = "cluster_two"
  host                   = var.disaster_recovery_enabled == true ? data.aws_eks_cluster.eks[local.recovery_region].endpoint : data.aws_eks_cluster.eks[local.main_region].endpoint
  cluster_ca_certificate = var.disaster_recovery_enabled == true ? base64decode(data.aws_eks_cluster.eks[local.recovery_region].certificate_authority[0].data) : base64decode(data.aws_eks_cluster.eks[local.main_region].certificate_authority[0].data)
  token                  = var.disaster_recovery_enabled == true ? data.aws_eks_cluster_auth.eks[local.recovery_region].token : data.aws_eks_cluster_auth.eks[local.main_region].token
  load_config_file       = false
}

provider "kubernetes" {
  alias                  = "cluster_one"
  host                   = data.aws_eks_cluster.eks[local.main_region].endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks[local.main_region].certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks[local.main_region].token
}

provider "kubernetes" {
  alias                  = "cluster_two"
  host                   = var.disaster_recovery_enabled == true ? data.aws_eks_cluster.eks[local.recovery_region].endpoint : data.aws_eks_cluster.eks[local.main_region].endpoint
  cluster_ca_certificate = var.disaster_recovery_enabled == true ? base64decode(data.aws_eks_cluster.eks[local.recovery_region].certificate_authority[0].data) : base64decode(data.aws_eks_cluster.eks[local.main_region].certificate_authority[0].data)
  token                  = var.disaster_recovery_enabled == true ? data.aws_eks_cluster_auth.eks[local.recovery_region].token : data.aws_eks_cluster_auth.eks[local.main_region].token
}
