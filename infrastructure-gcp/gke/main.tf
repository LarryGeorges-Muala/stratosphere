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
  main_region     = "asia-southeast1"
  recovery_region = "europe-west1"

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
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network
################################################################################

data "google_compute_network" "vpc" {
  for_each = tomap(local.disaster_recovery)
  name     = "${each.key}-vpc"
}

################################################################################
# Data - VPC Subnets
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork
################################################################################

data "google_compute_subnetwork" "vpc_subnet" {
  for_each = tomap(local.disaster_recovery)
  name     = "${each.key}-vpc-subnet"
  region   = each.key
}

################################################################################
# Cluster
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
################################################################################

resource "google_container_cluster" "gke" {
  for_each                 = tomap(local.disaster_recovery)
  name                     = "${each.key}-gke"
  location                 = each.key
  node_locations           = each.value[1]
  remove_default_node_pool = true
  initial_node_count       = 1
  enable_autopilot         = true
  deletion_protection      = false
  network                  = data.google_compute_network.vpc[each.key].name
  subnetwork               = data.google_compute_subnetwork.vpc_subnet[each.key].name

  ip_allocation_policy {
    services_secondary_range_name = data.google_compute_subnetwork.vpc_subnet[each.key].secondary_ip_range[0].range_name
    cluster_secondary_range_name  = data.google_compute_subnetwork.vpc_subnet[each.key].secondary_ip_range[1].range_name
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  addons_config {
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }
}

################################################################################
# Service Account
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
################################################################################

resource "google_service_account" "gke" {
  depends_on = [
    google_container_cluster.gke
  ]
  account_id                   = "stratoshpere-gke"
  display_name                 = "Service Account GKE"
  create_ignore_already_exists = true
}

################################################################################
# Node Pool
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
################################################################################

resource "google_container_node_pool" "gke_node_pool" {
  depends_on = [
    google_service_account.gke
  ]
  for_each   = tomap(local.disaster_recovery)
  name       = "${each.key}-gke-node-pool"
  cluster    = google_container_cluster.gke[each.key].name
  location   = each.key
  node_count = 1

  autoscaling {
    min_node_count  = 1
    max_node_count  = 30
    location_policy = "BALANCED"
  }

  node_config {
    machine_type    = "e2-medium"
    service_account = google_service_account.gke.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
