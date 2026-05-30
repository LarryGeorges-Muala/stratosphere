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
    "${local.main_region}" = []
    "${local.recovery_region}" = []
  }

  disaster_recovery = var.disaster_recovery_enabled == true ? local.main_and_recovery_region_setup : local.main_region_setup

  disaster_recovery_status = var.disaster_recovery_enabled == true ? "multi-region setup active" : "single-region setup active"

  tags = {
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# Data - Policy Document
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
################################################################################

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "replication_main" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.storage[local.main_region].arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = [
      "${aws_s3_bucket.storage[local.main_region].arn}/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = [
      "${aws_s3_bucket.storage[local.recovery_region].arn}/*"
    ]
  }
}

data "aws_iam_policy_document" "replication_recovery" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.storage[local.recovery_region].arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = [
      "${aws_s3_bucket.storage[local.recovery_region].arn}/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = [
      "${aws_s3_bucket.storage[local.main_region].arn}/*"
    ]
  }
}

################################################################################
# Roles
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
################################################################################

resource "aws_iam_role" "replication" {
  for_each = tomap(local.disaster_recovery)
  name               = "${each.key}-role-replication"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

################################################################################
# Policies
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
################################################################################

resource "aws_iam_policy" "replication_main" {
  depends_on = [
    aws_iam_role.replication
  ]
  name   = "${local.main_region}-policy-replication"
  policy = data.aws_iam_policy_document.replication_main.json
}

resource "aws_iam_policy" "replication_recovery" {
  depends_on = [
    aws_iam_policy.replication_main
  ]
  name   = "${local.recovery_region}-policy-replication"
  policy = data.aws_iam_policy_document.replication_recovery.json
}

################################################################################
# Roles Policy Attachment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
################################################################################

resource "aws_iam_role_policy_attachment" "replication_main" {
  depends_on = [
    aws_iam_policy.replication_recovery
  ]
  role       = aws_iam_role.replication[local.main_region].name
  policy_arn = aws_iam_policy.replication_main.arn
}

resource "aws_iam_role_policy_attachment" "replication_recovery" {
  depends_on = [
    aws_iam_role_policy_attachment.replication_main
  ]
  role       = aws_iam_role.replication[local.recovery_region].name
  policy_arn = aws_iam_policy.replication_recovery.arn
}

################################################################################
# S3
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
################################################################################

resource "aws_s3_bucket" "storage" {
  depends_on = [
    aws_iam_role_policy_attachment.replication_recovery
  ]
  for_each = tomap(local.disaster_recovery)
  region = each.key
  bucket           = "${each.key}-s3"
  bucket_namespace = "account-regional"
}

################################################################################
# S3 - ACL
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl
################################################################################

resource "aws_s3_bucket_acl" "storage" {
  depends_on = [
    aws_s3_bucket.storage
  ]
  for_each = tomap(local.disaster_recovery)
  region = each.key
  bucket = aws_s3_bucket.storage[each.key].id
  acl    = "private"
}

################################################################################
# S3 - Versioning
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning
################################################################################

resource "aws_s3_bucket_versioning" "storage" {
  depends_on = [
    aws_s3_bucket_acl.storage
  ]
  for_each = tomap(local.disaster_recovery)
  bucket = aws_s3_bucket.storage[each.key].id
  region = each.key
  versioning_configuration {
    status = "Enabled"
  }
}

################################################################################
# S3 - Replication
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration
################################################################################

resource "aws_s3_bucket_replication_configuration" "replication_main" {
  depends_on = [
    aws_s3_bucket_versioning.storage
  ]
  region = local.main_region

  role   = aws_iam_role.replication[local.main_region].arn
  bucket = aws_s3_bucket.storage[local.main_region].id

  rule {
    id = "${local.main_region}-replication"

    filter {
      prefix = ""
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.storage[local.recovery_region].arn
      storage_class = "STANDARD"
    }
  }
}

resource "aws_s3_bucket_replication_configuration" "replication_recovery" {
  depends_on = [
    aws_s3_bucket_replication_configuration.replication_main
  ]
  region = local.recovery_region

  role   = aws_iam_role.replication[local.recovery_region].arn
  bucket = aws_s3_bucket.storage[local.recovery_region].id

  rule {
    id = "${local.recovery_region}-replication"

    filter {
      prefix = ""
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.storage[local.main_region].arn
      storage_class = "STANDARD"
    }
  }
}
