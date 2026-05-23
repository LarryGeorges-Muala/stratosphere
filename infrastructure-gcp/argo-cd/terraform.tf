terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.33.0"
    }
    # https://registry.terraform.io/providers/hashicorp/helm/latest/docs
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
  }

  required_version = "~> 1.6"
}

provider "google" {
  project = "stratosphere-497017"
  region  = local.region
}

provider "helm" {
  alias = "cluster_one"
  kubernetes = {
    host  = "https://${data.google_container_cluster.gke[local.main_region].endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.gke[local.main_region].master_auth[0].cluster_ca_certificate
    )
  }
}

provider "helm" {
  alias = "cluster_two"
  kubernetes = var.disaster_recovery_enabled == true ? {
    host  = "https://${data.google_container_cluster.gke[local.recovery_region].endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.gke[local.recovery_region].master_auth[0].cluster_ca_certificate
    )
    } : {
    host  = "https://${data.google_container_cluster.gke[local.main_region].endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.gke[local.main_region].master_auth[0].cluster_ca_certificate
    )
  }
}
