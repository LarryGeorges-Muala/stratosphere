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
# Data - Subnets
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet
################################################################################

## Privates Subnets
data "aws_subnet" "vpc_private_subnet_1" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][0]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-private-subnet-1"]
  }
}

data "aws_subnet" "vpc_private_subnet_2" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][1]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-private-subnet-2"]
  }
}

data "aws_subnet" "vpc_private_subnet_3" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][2]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-private-subnet-3"]
  }
}

## Public Subnets
data "aws_subnet" "vpc_public_subnet_1" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][0]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-public-subnet-1"]
  }
}

data "aws_subnet" "vpc_public_subnet_2" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][1]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-public-subnet-2"]
  }
}

data "aws_subnet" "vpc_public_subnet_3" {
  for_each             = tomap(local.disaster_recovery)
  region               = each.key
  availability_zone_id = each.value[0][2]

  filter {
    name   = "tag:Name"
    values = ["${each.key}-public-subnet-3"]
  }
}

################################################################################
# Data - Security Groups
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group
################################################################################

data "aws_security_group" "ssh" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_ssh"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

data "aws_security_group" "http" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_http"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

data "aws_security_group" "https" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_https"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

data "aws_security_group" "efs" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_efs"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

################################################################################
# EFS
# https://registry.terraform.io/providers/-/aws/latest/docs/resources/efs_file_system
################################################################################

resource "aws_efs_file_system" "shared" {
  for_each = tomap(local.disaster_recovery)

  region = each.key

  creation_token = "${each.key}-efs"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    "Name"                     = "${each.key}-efs"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# EFS Replication
# https://registry.terraform.io/providers/-/aws/latest/docs/resources/efs_replication_configuration
################################################################################

resource "aws_efs_replication_configuration" "sync" {
  depends_on = [
    aws_efs_file_system.shared
  ]
  count                 = var.disaster_recovery_enabled ? 1 : 0
  region                = local.main_region
  source_file_system_id = aws_efs_file_system.shared[local.main_region].id

  destination {
    file_system_id = aws_efs_file_system.shared[local.recovery_region].id
    region         = local.recovery_region
  }
}

################################################################################
# EFS Mount Target
# https://registry.terraform.io/providers/-/aws/latest/docs/resources/efs_mount_target
################################################################################

resource "aws_efs_mount_target" "vpc_private_subnet_1" {
  depends_on = [
    aws_efs_replication_configuration.sync
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  file_system_id = aws_efs_file_system.shared[each.key].id
  subnet_id      = data.aws_subnet.vpc_private_subnet_1[each.key].id
  security_groups = [
    data.aws_security_group.efs[each.key].id
  ]
}

resource "aws_efs_mount_target" "vpc_private_subnet_2" {
  depends_on = [
    aws_efs_replication_configuration.sync
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  file_system_id = aws_efs_file_system.shared[each.key].id
  subnet_id      = data.aws_subnet.vpc_private_subnet_2[each.key].id
  security_groups = [
    data.aws_security_group.efs[each.key].id
  ]
}

resource "aws_efs_mount_target" "vpc_private_subnet_3" {
  depends_on = [
    aws_efs_replication_configuration.sync
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  file_system_id = aws_efs_file_system.shared[each.key].id
  subnet_id      = data.aws_subnet.vpc_private_subnet_3[each.key].id
  security_groups = [
    data.aws_security_group.efs[each.key].id
  ]
}

################################################################################
# EFS Access Point
# https://registry.terraform.io/providers/-/aws/latest/docs/resources/efs_access_point
################################################################################

resource "aws_efs_access_point" "shared" {
  depends_on = [
    aws_efs_mount_target.shared
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  file_system_id = aws_efs_file_system.shared[each.key].id
}
