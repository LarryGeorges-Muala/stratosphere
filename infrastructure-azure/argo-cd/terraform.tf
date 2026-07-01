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

provider "helm" {
  alias = "cluster_one"
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.cluster_ca_certificate)
    token                  = data.external.this.result.token
  }
}

provider "helm" {
  alias = "cluster_two"
  kubernetes = var.disaster_recovery_enabled == true ? {
    host                   = data.azurerm_kubernetes_cluster.aks[local.recovery_region].kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks[local.recovery_region].kube_config.0.cluster_ca_certificate)
    token                  = data.external.this.result.token
    } : {
    host                   = data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks[local.main_region].kube_config.0.cluster_ca_certificate)
    token                  = data.external.this.result.token
  }
}
