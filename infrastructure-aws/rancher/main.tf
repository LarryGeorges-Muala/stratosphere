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
# Data - EC2 AMIs
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami
################################################################################

data "aws_ami" "amazon_ami" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["099720109477"] # Canonical
}

################################################################################
# Roles
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
################################################################################

resource "aws_iam_role" "iam_ec2" {
  name = "${local.region}-iam-ec2"

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
          Service = [
            "ec2.amazonaws.com",
            "s3.amazonaws.com"
          ]
        }
      },
    ]
  })
}

################################################################################
# Policies
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
################################################################################

resource "aws_iam_policy" "iam_ec2" {
  depends_on = [
    aws_iam_role.iam_ec2
  ]

  name = "${local.region}-iam-ec2"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "iam:PassedToService" : [
              "ec2.amazonaws.com",
              "s3.amazonaws.com"
            ]
          }
        }
      },
      {
        Action = [
          "ec2:Describe*",
          "ec2:Search*",
          "ec2:Get*",
          "s3:List*",
          "iam:ListInstanceProfiles"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

################################################################################
# Roles Policy Attachment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
################################################################################

resource "aws_iam_role_policy_attachment" "iam_ec2" {
  depends_on = [
    aws_iam_role.iam_ec2,
    aws_iam_policy.iam_ec2
  ]
  role       = aws_iam_role.iam_ec2.name
  policy_arn = aws_iam_policy.iam_ec2.arn
}

################################################################################
# EC2 Instance Profile
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile.html
################################################################################

resource "aws_iam_instance_profile" "iam_ec2" {
  depends_on = [
    aws_iam_role_policy_attachment.iam_ec2
  ]
  name = "iam_ec2"
  role = aws_iam_role.iam_ec2.name
}

################################################################################
# EFS
# https://registry.terraform.io/providers/-/aws/latest/docs/resources/efs_file_system
################################################################################

resource "aws_efs_file_system" "origin" {
  depends_on = [
    aws_iam_instance_profile.iam_ec2
  ]
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
    aws_efs_file_system.origin
  ]
  count                 = var.disaster_recovery_enabled ? 1 : 0
  region                = local.main_region
  source_file_system_id = aws_efs_file_system.origin[local.main_region].id

  destination {
    file_system_id = aws_efs_file_system.origin[local.recovery_region].id
    region         = local.recovery_region
  }
}

################################################################################
# EFS Mount Target
# https://registry.terraform.io/providers/-/aws/latest/docs/resources/efs_mount_target
################################################################################

resource "aws_efs_mount_target" "origin" {
  depends_on = [
    aws_efs_replication_configuration.sync
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  file_system_id = aws_efs_file_system.origin[each.key].id
  subnet_id      = data.aws_subnet.vpc_public_subnet_1[each.key].id
  security_groups = [
    data.aws_security_group.efs[each.key].id
  ]
}

################################################################################
# EFS Access Point
# https://registry.terraform.io/providers/-/aws/latest/docs/resources/efs_access_point
################################################################################

resource "aws_efs_access_point" "origin" {
  depends_on = [
    aws_efs_mount_target.origin
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  file_system_id = aws_efs_file_system.origin[each.key].id
}

################################################################################
# EC2
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
################################################################################

resource "aws_instance" "rancher" {
  depends_on = [
    aws_efs_access_point.origin
  ]
  for_each      = tomap(local.disaster_recovery)
  region        = each.key
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  subnet_id     = data.aws_subnet.vpc_public_subnet_1[each.key].id

  vpc_security_group_ids = [
    data.aws_security_group.ssh[each.key].id,
    data.aws_security_group.http[each.key].id,
    data.aws_security_group.https[each.key].id,
    data.aws_security_group.efs[each.key].id
  ]

  root_block_device {
    volume_size = 30
  }

  user_data = templatefile("${path.module}/scripts/bootstrap-rancher.sh", {
    efs = "${aws_efs_file_system.origin[each.key].id}.efs.${each.key}.amazonaws.com"
  })

  user_data_replace_on_change = true

  iam_instance_profile = aws_iam_instance_profile.iam_ec2.name

  tags = {
    "Name"                     = "${each.key}-rancher"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# Data - Target Groups
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_target_group
################################################################################

data "aws_lb_target_group" "rancher" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "${each.key}-tg-rancher"
  tags = {
    "elbv2.k8s.aws/cluster" = "${each.key}-vpc"
  }
}

################################################################################
# Target Group Attachment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment
################################################################################

resource "aws_lb_target_group_attachment" "rancher" {
  depends_on = [
    aws_instance.rancher
  ]
  for_each         = tomap(local.disaster_recovery)
  region           = each.key
  target_group_arn = data.aws_lb_target_group.rancher[each.key].arn
  target_id        = aws_instance.rancher[each.key].private_ip
  port             = 80
}
