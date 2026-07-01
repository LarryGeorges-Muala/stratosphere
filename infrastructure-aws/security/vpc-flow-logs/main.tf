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
# Data - Policy Document
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
################################################################################

## Flow Logs - Assume Role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

## Cloudwatch
data "aws_iam_policy_document" "vpc_logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

################################################################################
# Roles
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
################################################################################

resource "aws_iam_role" "vpc_logs" {
  name               = "${local.region}-vpc-logs"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

################################################################################
# Roles Policies
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy
################################################################################

resource "aws_iam_role_policy" "vpc_logs" {
  depends_on = [
    aws_iam_role.vpc_logs
  ]
  name   = "${local.region}-vpc-logs"
  role   = aws_iam_role.vpc_logs.id
  policy = data.aws_iam_policy_document.vpc_logs.json
}

################################################################################
# Cloudwatch - Log Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group
################################################################################

resource "aws_cloudwatch_log_group" "vpc_logs" {
  depends_on = [
    aws_iam_role_policy.vpc_logs
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  name                        = "${each.key}-vpc-logs"
  log_group_class             = "STANDARD"
  retention_in_days           = 90
  skip_destroy                = false
  deletion_protection_enabled = false

  tags = {
    "Name"                     = "${each.key}-vpc-logs"
    "category"                 = "vpc"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_cloudwatch_log_group" "subnet_public_1_logs" {
  depends_on = [
    aws_cloudwatch_log_group.vpc_logs
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  name                        = "${each.key}-subnet-public-1-logs"
  log_group_class             = "STANDARD"
  retention_in_days           = 90
  skip_destroy                = false
  deletion_protection_enabled = false

  tags = {
    "Name"                     = "${each.key}-subnet-public-1-logs"
    "category"                 = "vpc"
    "resource_id"              = data.aws_subnet.vpc_public_subnet_1[each.key].id
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_cloudwatch_log_group" "subnet_public_2_logs" {
  depends_on = [
    aws_cloudwatch_log_group.subnet_public_1_logs
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  name                        = "${each.key}-subnet-public-2-logs"
  log_group_class             = "STANDARD"
  retention_in_days           = 90
  skip_destroy                = false
  deletion_protection_enabled = false

  tags = {
    "Name"                     = "${each.key}-subnet-public-2-logs"
    "category"                 = "vpc"
    "resource_id"              = data.aws_subnet.vpc_public_subnet_2[each.key].id
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_cloudwatch_log_group" "subnet_public_3_logs" {
  depends_on = [
    aws_cloudwatch_log_group.subnet_public_2_logs
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  name                        = "${each.key}-subnet-public-3-logs"
  log_group_class             = "STANDARD"
  retention_in_days           = 90
  skip_destroy                = false
  deletion_protection_enabled = false

  tags = {
    "Name"                     = "${each.key}-subnet-public-3-logs"
    "category"                 = "vpc"
    "resource_id"              = data.aws_subnet.vpc_public_subnet_3[each.key].id
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# VPC Flow Logs
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log
################################################################################

resource "aws_flow_log" "vpc_logs" {
  depends_on = [
    aws_cloudwatch_log_group.subnet_public_3_logs
  ]
  for_each        = tomap(local.disaster_recovery)
  region          = each.key
  iam_role_arn    = aws_iam_role.vpc_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_logs[each.key].arn
  traffic_type    = "ALL"
  vpc_id          = data.aws_vpc.vpc[each.key].id

  tags = {
    "Name"                     = "${each.key}-vpc-logs"
    "category"                 = "vpc"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_flow_log" "subnet_public_1_logs" {
  depends_on = [
    aws_flow_log.vpc_logs
  ]
  for_each        = tomap(local.disaster_recovery)
  region          = each.key
  iam_role_arn    = aws_iam_role.vpc_logs.arn
  log_destination = aws_cloudwatch_log_group.subnet_public_1_logs[each.key].arn
  traffic_type    = "ALL"
  subnet_id       = data.aws_subnet.vpc_public_subnet_1[each.key].id

  tags = {
    "Name"                     = "${each.key}-subnet-public-1-logs"
    "category"                 = "vpc"
    "resource_id"              = data.aws_subnet.vpc_public_subnet_1[each.key].id
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_flow_log" "subnet_public_2_logs" {
  depends_on = [
    aws_flow_log.subnet_public_1_logs
  ]
  for_each        = tomap(local.disaster_recovery)
  region          = each.key
  iam_role_arn    = aws_iam_role.vpc_logs.arn
  log_destination = aws_cloudwatch_log_group.subnet_public_2_logs[each.key].arn
  traffic_type    = "ALL"
  subnet_id       = data.aws_subnet.vpc_public_subnet_2[each.key].id

  tags = {
    "Name"                     = "${each.key}-subnet-public-2-logs"
    "category"                 = "vpc"
    "resource_id"              = data.aws_subnet.vpc_public_subnet_2[each.key].id
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_flow_log" "subnet_public_3_logs" {
  depends_on = [
    aws_flow_log.subnet_public_2_logs
  ]
  for_each        = tomap(local.disaster_recovery)
  region          = each.key
  iam_role_arn    = aws_iam_role.vpc_logs.arn
  log_destination = aws_cloudwatch_log_group.subnet_public_3_logs[each.key].arn
  traffic_type    = "ALL"
  subnet_id       = data.aws_subnet.vpc_public_subnet_3[each.key].id

  tags = {
    "Name"                     = "${each.key}-subnet-public-3-logs"
    "category"                 = "vpc"
    "resource_id"              = data.aws_subnet.vpc_public_subnet_3[each.key].id
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}
