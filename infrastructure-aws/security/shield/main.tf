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
  main_region     = "ap-southeast-1"
  recovery_region = "eu-west-1"

  region = local.main_region

  main_availability_zone_ids     = data.aws_availability_zones.asia.zone_ids
  recovery_availability_zone_ids = data.aws_availability_zones.europe.zone_ids

  main_region_setup = {
    "${local.main_region}" = [
      local.main_availability_zone_ids
    ]
  }

  main_and_recovery_region_setup = {
    "${local.main_region}" = [
      local.main_availability_zone_ids
    ]
    "${local.recovery_region}" = [
      local.recovery_availability_zone_ids
    ]
  }

  disaster_recovery = var.disaster_recovery_enabled == true ? local.main_and_recovery_region_setup : local.main_region_setup

  disaster_recovery_status = var.disaster_recovery_enabled == true ? "multi-region setup active" : "single-region setup active"

  tags = {
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# Data - VPC Availability Zones
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones
################################################################################

data "aws_availability_zones" "africa" {
  state = "available"

  filter {
    name   = "region-name"
    values = ["af-south-1"]
  }
}

data "aws_availability_zones" "asia" {
  state  = "available"
  region = "ap-southeast-1"
}

data "aws_availability_zones" "europe" {
  state  = "available"
  region = "eu-west-1"
}

################################################################################
# Data - Caller Identity
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# Data - VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc
################################################################################

data "aws_vpc" "vpc" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key

  filter {
    name   = "tag:Name"
    values = ["${each.key}-vpc"]
  }
}

################################################################################
# Data - Eip
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eip
################################################################################

data "aws_eip" "vpc_nat_eip" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key

  filter {
    name   = "tag:Name"
    values = ["${each.key}-nat"]
  }

  filter {
    name   = "tag:vpc_id"
    values = ["${data.aws_vpc.vpc[each.key].id}"]
  }
}

################################################################################
# Data - NLB
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb
################################################################################

data "aws_lb" "game_2048" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  tags = {
    "Name"                  = "${each.key}-nlb-game-2048"
    "vpc_id"                = data.aws_vpc.vpc[each.key].id
    "vpc_name"              = "${each.key}-vpc"
    "elbv2.k8s.aws/cluster" = "${each.key}-vpc"
  }
}

################################################################################
# Shield
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/shield_protection
################################################################################

resource "aws_shield_protection" "eip_shield" {
  for_each     = tomap(local.disaster_recovery)
  name         = "${each.key}-eip-shield"
  resource_arn = "arn:aws:ec2:${each.key}:${data.aws_caller_identity.current.account_id}:eip-allocation/${data.aws_eip.vpc_nat_eip[each.key].id}"

  tags = {
    "Name"                     = "${each.key}-eip-shield"
    "category"                 = "eip"
    "resource_id"              = data.aws_eip.vpc_nat_eip[each.key].id
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_shield_protection" "nlb_game_2048_shield" {
  for_each     = tomap(local.disaster_recovery)
  name         = "${each.key}-nlb-game-2048-shield"
  resource_arn = data.aws_lb.game_2048[each.key].arn

  tags = {
    "Name"                     = "${each.key}-nlb-game-2048-shield"
    "category"                 = "nlb"
    "resource_id"              = data.aws_lb.game_2048[each.key].id
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}
