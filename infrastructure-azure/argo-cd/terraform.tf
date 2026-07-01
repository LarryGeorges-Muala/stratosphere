terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
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

provider "azurerm" {
  features {}
}

provider "kubectl" {
  host                   = data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.cluster_ca_certificate)
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.client_key)
  load_config_file       = false
}

provider "helm" {
  alias = "cluster_one"
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.cluster_ca_certificate)
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.client_key)
    load_config_file       = false
  }
}

provider "helm" {
  alias = "cluster_two"
  kubernetes = var.disaster_recovery_enabled == true ? {
    host                   = data.azurerm_kubernetes_cluster.aks[local.recovery_region].kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks[local.recovery_region].kube_config.0.cluster_ca_certificate)
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks[local.recovery_region].kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.aks[local.recovery_region].kube_config.0.client_key)
    load_config_file       = false
    } : {
    host                   = data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.cluster_ca_certificate)
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.client_key)
    load_config_file       = false
  }
}
