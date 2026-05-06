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
# Data - Partitions
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition
################################################################################

data "aws_partition" "current" {}

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
# Data - Policy Document
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
################################################################################

## Cloud Trail
data "aws_iam_policy_document" "cloud_trail" {
  depends_on = [
    aws_s3_bucket.cloud_trail
  ]
  for_each = tomap(local.disaster_recovery)
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloud_trail[each.key].arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${each.key}:${data.aws_caller_identity.current.account_id}:trail/${each.key}-cloud-trail"]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloud_trail[each.key].arn}/prefix/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${each.key}:${data.aws_caller_identity.current.account_id}:trail/${each.key}-cloud-trail"]
    }
  }
}

################################################################################
# Roles
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
################################################################################

resource "aws_iam_role" "cloudwatch_cloudtrail_logs" {
  name = "${local.region}-cloudwatch-cloudtrail-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      },
    ]
  })
}

################################################################################
# Policies
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
################################################################################

resource "aws_iam_policy" "cloudwatch_cloudtrail_logs" {
  depends_on = [
    aws_iam_role.cloudwatch_cloudtrail_logs
  ]
  for_each = tomap(local.disaster_recovery)
  name     = "${each.key}-cloudwatch-cloudtrail-logs"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.cloud_trail[each.key].arn}:*"
      },
      {
        Action = [
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.cloud_trail[each.key].arn}:*"
      },
    ]
  })
}

################################################################################
# Roles Policy Attachment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
################################################################################

resource "aws_iam_role_policy_attachment" "cloudwatch_cloudtrail_logs" {
  depends_on = [
    aws_iam_policy.cloudwatch_cloudtrail_logs
  ]
  for_each   = tomap(local.disaster_recovery)
  role       = aws_iam_role.cloudwatch_cloudtrail_logs.name
  policy_arn = aws_iam_policy.cloudwatch_cloudtrail_logs[each.key].arn
}

################################################################################
# S3
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
################################################################################

resource "aws_s3_bucket" "cloud_trail" {
  for_each      = tomap(local.disaster_recovery)
  region        = each.key
  bucket        = "${each.key}-cloud-trail-collector"
  force_destroy = true

  tags = {
    "Name"                     = "${each.key}-cloud-trail-collector"
    "category"                 = "vpc"
    "resource_id"              = "s3://${each.key}-cloud-trail-collector"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# S3 Policies
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy
################################################################################

resource "aws_s3_bucket_policy" "cloud_trail" {
  depends_on = [
    aws_s3_bucket.cloud_trail,
    data.aws_iam_policy_document.cloud_trail
  ]
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  bucket   = aws_s3_bucket.cloud_trail[each.key].id
  policy   = data.aws_iam_policy_document.cloud_trail[each.key].json
}

################################################################################
# S3 - Intelligent Tiering
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_intelligent_tiering_configuration
################################################################################

resource "aws_s3_bucket_intelligent_tiering_configuration" "cloud_trail" {
  depends_on = [
    aws_s3_bucket_policy.cloud_trail
  ]

  for_each = tomap(local.disaster_recovery)
  region   = each.key
  bucket   = aws_s3_bucket.cloud_trail[each.key].id
  name     = "${each.key}-tiering-cloud-trail-collector"
  status   = "Enabled"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}

################################################################################
# Cloudwatch - Log Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group
################################################################################

resource "aws_cloudwatch_log_group" "cloud_trail" {
  depends_on = [
    aws_s3_bucket_intelligent_tiering_configuration.cloud_trail
  ]
  for_each                    = tomap(local.disaster_recovery)
  region                      = each.key
  name                        = "${each.key}-cloud-trail-logs"
  log_group_class             = "STANDARD"
  retention_in_days           = 90
  skip_destroy                = false
  deletion_protection_enabled = false

  tags = {
    "Name"                     = "${each.key}-cloud-trail-logs"
    "category"                 = "cloud-trail"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# Cloudtrail
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail
################################################################################

resource "aws_cloudtrail" "cloud_trail" {
  depends_on = [
    aws_cloudwatch_log_group.cloud_trail
  ]
  for_each                      = tomap(local.disaster_recovery)
  region                        = each.key
  name                          = "${each.key}-cloud-trail"
  s3_bucket_name                = aws_s3_bucket.cloud_trail[each.key].id
  s3_key_prefix                 = "prefix"
  include_global_service_events = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloud_trail[each.key].arn}:*" # CloudTrail requires the Log Stream wildcard
  cloud_watch_logs_role_arn     = aws_iam_role.cloudwatch_cloudtrail_logs.arn

  tags = {
    "Name"                     = "${each.key}-cloud-trail"
    "category"                 = "cloud-trail"
    "resource_id"              = aws_s3_bucket.cloud_trail[each.key].id
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}
