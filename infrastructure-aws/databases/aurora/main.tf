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
# DB Subnets
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group
################################################################################

resource "aws_db_subnet_group" "default" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "main"

  subnet_ids = [
    data.aws_subnet.vpc_private_subnet_1[each.key].id,
    data.aws_subnet.vpc_private_subnet_2[each.key].id,
    data.aws_subnet.vpc_private_subnet_3[each.key].id,
    data.aws_subnet.vpc_public_subnet_1[each.key].id,
    data.aws_subnet.vpc_public_subnet_2[each.key].id,
    data.aws_subnet.vpc_public_subnet_3[each.key].id
  ]

  tags = {
    "Name"                     = "main"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# Aurora Global
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_global_cluster
################################################################################

resource "aws_rds_global_cluster" "aurora" {
  depends_on = [
    aws_db_subnet_group.default
  ]
  global_cluster_identifier = "global-aurora"
  engine                    = "aurora-postgresql"
  engine_version            = "11.9"
  database_name             = "aurora_db"
  tags = {
    "Name"                     = "global-aurora"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# Aurora KMS Key
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key
################################################################################

resource "aws_kms_key" "aurora" {
  depends_on = [
    aws_rds_global_cluster.aurora
  ]
  for_each                = tomap(local.disaster_recovery)
  region                  = each.key
  description             = "${each.key} symmetric encryption KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-${each.key}"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      },
      # {
      #   Sid    = "Allow administration of the key"
      #   Effect = "Allow"
      #   Principal = {
      #     AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/Alice"
      #   },
      #   Action = [
      #     "kms:ReplicateKey",
      #     "kms:Create*",
      #     "kms:Describe*",
      #     "kms:Enable*",
      #     "kms:List*",
      #     "kms:Put*",
      #     "kms:Update*",
      #     "kms:Revoke*",
      #     "kms:Disable*",
      #     "kms:Get*",
      #     "kms:Delete*",
      #     "kms:ScheduleKeyDeletion",
      #     "kms:CancelKeyDeletion"
      #   ],
      #   Resource = "*"
      # },
      # {
      #   Sid    = "Allow use of the key"
      #   Effect = "Allow"
      #   Principal = {
      #     AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/Bob"
      #   },
      #   Action = [
      #     "kms:DescribeKey",
      #     "kms:Encrypt",
      #     "kms:Decrypt",
      #     "kms:ReEncrypt*",
      #     "kms:GenerateDataKey",
      #     "kms:GenerateDataKeyWithoutPlaintext"
      #   ],
      #   Resource = "*"
      # }
    ]
  })
}

################################################################################
# Aurora RDS Cluster
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster
################################################################################

resource "aws_rds_cluster" "primary" {
  depends_on = [
    aws_kms_key.aurora
  ]
  provider       = aws.primary
  engine         = aws_rds_global_cluster.aurora.engine
  engine_version = aws_rds_global_cluster.aurora.engine_version
  availability_zones = [
    local.main_availability_zone_names[0],
    local.main_availability_zone_names[1],
    local.main_availability_zone_names[2]
  ]
  cluster_identifier = "aurora-primary-cluster"
  master_username    = "username"
  master_password    = "satsukimae"
  # manage_master_user_password = true
  # master_user_secret_kms_key_id = aws_kms_key.aurora[local.main_region].key_id
  database_name             = "aurora_db"
  global_cluster_identifier = aws_rds_global_cluster.aurora.id
  db_subnet_group_name      = "main"
  backup_retention_period   = 35
  preferred_backup_window   = "07:00-09:00"
  final_snapshot_identifier = "aurora-primary-cluster"
  skip_final_snapshot       = true
}

resource "aws_rds_cluster" "secondary" {
  depends_on = [
    aws_rds_cluster.primary
  ]
  count          = var.disaster_recovery_enabled ? 1 : 0
  provider       = aws.secondary
  engine         = aws_rds_global_cluster.aurora.engine
  engine_version = aws_rds_global_cluster.aurora.engine_version
  availability_zones = [
    local.recovery_availability_zone_names[0],
    local.recovery_availability_zone_names[1],
    local.recovery_availability_zone_names[2]
  ]
  cluster_identifier             = "aurora-secondary-cluster"
  global_cluster_identifier      = aws_rds_global_cluster.aurora.id
  skip_final_snapshot            = true
  db_subnet_group_name           = "main"
  backup_retention_period        = 35
  preferred_backup_window        = "07:00-09:00"
  enable_global_write_forwarding = false

  lifecycle {
    ignore_changes = [
      replication_source_identifier
    ]
  }
}

################################################################################
# Aurora RDS Cluster Instance
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance
################################################################################

resource "aws_rds_cluster_instance" "primary" {
  depends_on = [
    aws_rds_cluster.secondary
  ]
  count                = local.db_read_replicas
  provider             = aws.primary
  engine               = aws_rds_global_cluster.aurora.engine
  engine_version       = aws_rds_global_cluster.aurora.engine_version
  identifier           = "aurora-primary-cluster-instance-${count.index}"
  cluster_identifier   = aws_rds_cluster.primary.id
  instance_class       = "db.r4.large"
  db_subnet_group_name = "main"
}

resource "aws_rds_cluster_instance" "secondary" {
  depends_on = [
    aws_rds_cluster_instance.primary
  ]
  count                = var.disaster_recovery_enabled ? local.db_read_replicas : 0
  provider             = aws.secondary
  engine               = aws_rds_global_cluster.aurora.engine
  engine_version       = aws_rds_global_cluster.aurora.engine_version
  identifier           = "aurora-secondary-cluster-instance-${count.index}"
  cluster_identifier   = aws_rds_cluster.secondary[0].id
  instance_class       = "db.r4.large"
  db_subnet_group_name = "main"
}

################################################################################
# Aurora RDS Reader Endpoint
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_endpoint
################################################################################

resource "aws_rds_cluster_endpoint" "primary" {
  depends_on = [
    aws_rds_cluster_instance.secondary
  ]
  provider                    = aws.primary
  cluster_identifier          = aws_rds_cluster.primary.id
  cluster_endpoint_identifier = "reader"
  custom_endpoint_type        = "READER"

  excluded_members = []
}
