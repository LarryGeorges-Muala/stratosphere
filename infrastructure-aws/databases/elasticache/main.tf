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

  main_availability_zone_names     = data.aws_availability_zones.asia.names
  recovery_availability_zone_names = data.aws_availability_zones.europe.names

  main_region_setup = {
    "${local.main_region}" = [
      local.main_availability_zone_ids,
      local.main_availability_zone_names
    ]
  }

  main_and_recovery_region_setup = {
    "${local.main_region}" = [
      local.main_availability_zone_ids,
      local.main_availability_zone_names
    ]
    "${local.recovery_region}" = [
      local.recovery_availability_zone_ids,
      local.recovery_availability_zone_names
    ]
  }

  db_read_replicas = 3

  disaster_recovery = var.disaster_recovery_enabled == true ? local.main_and_recovery_region_setup : local.main_region_setup

  disaster_recovery_status = var.disaster_recovery_enabled == true ? "multi-region setup active" : "single-region setup active"

  tags = {
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# Data - Caller Identity
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
################################################################################

## Local Identity
data "aws_caller_identity" "current" {}

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

data "aws_security_group" "redis" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_redis"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

################################################################################
# Elasticache Subnets
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group
################################################################################

resource "aws_elasticache_subnet_group" "default" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "main"

  subnet_ids = [
    data.aws_subnet.vpc_private_subnet_1[each.key].id,
    data.aws_subnet.vpc_private_subnet_2[each.key].id,
    data.aws_subnet.vpc_private_subnet_3[each.key].id
  ]

  tags = {
    "Name"                     = "main"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# Elasticache Global Replication Group - Redis
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_global_replication_group
################################################################################

resource "aws_elasticache_global_replication_group" "global" {
  global_replication_group_id_suffix = "global-redis"
  primary_replication_group_id       = aws_elasticache_replication_group.primary.id
}

################################################################################
# Elasticache Replication Group - Redis
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group
################################################################################

resource "aws_elasticache_replication_group" "primary" {
  region                     = local.main_region
  engine                     = "redis"
  automatic_failover_enabled = true
  multi_az_enabled           = true

  preferred_cache_cluster_azs = [
    local.main_availability_zone_names[0],
    local.main_availability_zone_names[1],
    local.main_availability_zone_names[2]
  ]

  replication_group_id     = "${local.main_region}-replication"
  description              = "${local.main_region} replication group"
  node_type                = "cache.m5.large"
  num_cache_clusters       = 4
  parameter_group_name     = "default.redis7"
  port                     = 6379
  subnet_group_name        = aws_elasticache_subnet_group.default[local.main_region].name
  snapshot_window          = "07:00-09:00"
  snapshot_retention_limit = 35

  security_group_ids = [
    data.aws_security_group.redis[local.main_region].id
  ]

  # log_delivery_configuration {
  #   destination      = aws_cloudwatch_log_group.example.name
  #   destination_type = "cloudwatch-logs"
  #   log_format       = "text"
  #   log_type         = "slow-log"
  # }
  # log_delivery_configuration {
  #   destination      = aws_kinesis_firehose_delivery_stream.example.name
  #   destination_type = "kinesis-firehose"
  #   log_format       = "json"
  #   log_type         = "engine-log"
  # }

  lifecycle {
    ignore_changes = [num_cache_clusters]
  }
}

resource "aws_elasticache_replication_group" "secondary" {
  count                       = var.disaster_recovery_enabled ? 1 : 0
  region                      = local.recovery_region
  replication_group_id        = "${local.recovery_region}-secondary"
  description                 = "${local.recovery_region} replication group"
  global_replication_group_id = aws_elasticache_global_replication_group.global.global_replication_group_id
  num_cache_clusters          = aws_elasticache_replication_group.primary.num_cache_clusters
}