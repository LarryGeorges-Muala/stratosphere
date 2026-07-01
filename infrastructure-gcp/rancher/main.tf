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

  main_vpc_cidr_block     = "10.0.0.0/16"
  recovery_vpc_cidr_block = "172.16.0.0/16"

  # main_availability_zone_ids     = data.google_compute_zones.asia.zone_ids
  # recovery_availability_zone_ids = data.google_compute_zones.europe.zone_ids
  main_availability_zone_ids = [
    "asia-southeast1-a",
    "asia-southeast1-b",
    "asia-southeast1-c"
  ]
  recovery_availability_zone_ids = [
    "europe-west1-b",
    "europe-west1-c",
    "europe-west1-d"
  ]

  # main_availability_zone_names     = data.google_compute_zones.asia.names
  # recovery_availability_zone_names = data.google_compute_zones.europe.names
  main_availability_zone_names = [
    "asia-southeast1-a",
    "asia-southeast1-b",
    "asia-southeast1-c"
  ]
  recovery_availability_zone_names = [
    "europe-west1-b",
    "europe-west1-c",
    "europe-west1-d"
  ]

  main_region_setup = {
    "${local.main_region}" = [
      "${local.main_vpc_cidr_block}",
      local.main_availability_zone_ids,
      local.main_availability_zone_names,
      "${local.main_vpc_cidr_block}"
    ]
  }

  main_and_recovery_region_setup = {
    "${local.main_region}" = [
      "${local.main_vpc_cidr_block}",
      local.main_availability_zone_ids,
      local.main_availability_zone_names,
      "${local.recovery_vpc_cidr_block}"
    ]
    "${local.recovery_region}" = [
      "${local.recovery_vpc_cidr_block}",
      local.recovery_availability_zone_ids,
      local.recovery_availability_zone_names,
      "${local.main_vpc_cidr_block}"
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
# Service Account
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
################################################################################

resource "google_service_account" "rancher" {
  account_id                   = "stratoshpere-rancher"
  display_name                 = "Service Account Rancher"
  create_ignore_already_exists = true
}

################################################################################
# Instance
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
################################################################################

resource "google_compute_instance" "rancher" {
  depends_on = [
    google_service_account.rancher
  ]
  for_each     = tomap(local.disaster_recovery)
  name         = "${each.key}-rancher"
  zone         = each.value[1][0]
  machine_type = "n2-standard-2"

  network_interface {
    network    = data.google_compute_network.vpc[each.key].name
    subnetwork = data.google_compute_subnetwork.vpc_subnet[each.key].name
    access_config {
    }
  }

  boot_disk {
    auto_delete = true
    device_name = "${each.key}-rancher-boot"
    mode        = "READ_WRITE"
    initialize_params {
      image        = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size         = 30
      type         = "pd-standard"
      architecture = "x86_64"
    }
  }

  metadata = {
    environment = "dev"
  }

  metadata_startup_script = file("${path.module}/scripts/bootstrap-rancher.sh")

  service_account {
    email = google_service_account.default.email
    scopes = [
      "cloud-platform"
    ]
  }
}
