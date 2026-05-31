terraform {
  required_providers {
    # https://registry.terraform.io/providers/tehcyx/kind/latest/docs
    kind = {
      source  = "tehcyx/kind"
      version = "0.11.0"
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

provider "kind" {
  # Configuration options
}

provider "kubectl" {
  host                   = kind_cluster.default.endpoint
  client_certificate     = kind_cluster.default.client_certificate
  client_key             = kind_cluster.default.client_key
  cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  load_config_file       = false
}

provider "helm" {
  kubernetes = {
    host                   = kind_cluster.default.endpoint
    client_certificate     = kind_cluster.default.client_certificate
    client_key             = kind_cluster.default.client_key
    cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  }
}

provider "kubernetes" {
  host                   = kind_cluster.default.endpoint
  client_certificate     = kind_cluster.default.client_certificate
  client_key             = kind_cluster.default.client_key
  cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
}
