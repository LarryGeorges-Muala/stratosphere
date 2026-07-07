###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
###############################################################################

################################################################################
# VPC Availability Zones
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones
################################################################################

data "google_compute_zones" "asia" {
  region = "asia-southeast1"
}

data "google_compute_zones" "europe" {
  region = "europe-west1"
}

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
# Filestore
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/filestore_instance
################################################################################

resource "google_filestore_instance" "storage" {
  name     = "${local.main_region}-storage"
  location = local.main_region
  tier     = "BASIC_HDD"

  file_shares {
    capacity_gb = 1024
    name        = "${local.main_region}-storage-unit"
  }

  networks {
    network = "default"
    modes   = ["MODE_IPV4"]
  }
}

resource "google_filestore_instance" "replica" {
  name     = "${local.recovery_region}-storage"
  location = local.recovery_region
  tier     = "BASIC_HDD"

  file_shares {
    capacity_gb = 1024
    name        = "${local.recovery_region}-storage-unit"
  }

  networks {
    network = "default"
    modes   = ["MODE_IPV4"]
  }

  initial_replication {
    role = "STANDBY"
    replicas {
      peer_instance = google_filestore_instance.storage.id
    }
  }
}
