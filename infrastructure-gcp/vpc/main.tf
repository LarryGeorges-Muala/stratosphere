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
# VPC
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
################################################################################

resource "google_compute_network" "vpc" {
  for_each = tomap(local.disaster_recovery)

  name                            = "${each.key}-vpc"
  auto_create_subnetworks         = false
  mtu                             = 1460
  routing_mode                    = "REGIONAL"
  enable_ula_internal_ipv6        = false
  delete_default_routes_on_create = false
}

################################################################################
# VPC Subnets
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
################################################################################

resource "google_compute_subnetwork" "vpc_subnet" {
  depends_on = [
    google_compute_network.vpc
  ]

  for_each = tomap(local.disaster_recovery)

  name = "${each.key}-vpc-subnet"

  ip_cidr_range = each.value[0]
  region        = each.key
  network       = google_compute_network.vpc[each.key].id

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.0.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.1.0/24"
  }

  log_config {
    aggregation_interval = "INTERVAL_5_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
