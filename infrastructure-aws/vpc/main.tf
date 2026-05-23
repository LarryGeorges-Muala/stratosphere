###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
###############################################################################

################################################################################
# VPC Availability Zones
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
# Locals
################################################################################

locals {
  main_region     = "ap-southeast-1"
  recovery_region = "eu-west-1"

  region = local.main_region

  main_vpc_cidr_block     = "10.0.0.0/16"
  recovery_vpc_cidr_block = "172.16.0.0/16"

  main_availability_zone_ids     = data.aws_availability_zones.asia.zone_ids
  recovery_availability_zone_ids = data.aws_availability_zones.europe.zone_ids

  main_availability_zone_names     = data.aws_availability_zones.asia.names
  recovery_availability_zone_names = data.aws_availability_zones.europe.names

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
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
# https://www.ipaddressguide.com/cidr
################################################################################

resource "aws_vpc" "vpc" {
  for_each = tomap(local.disaster_recovery)

  region     = each.key
  cidr_block = each.value[0]

  ipv4_ipam_pool_id   = null
  ipv4_netmask_length = null

  assign_generated_ipv6_cidr_block     = false
  ipv6_cidr_block                      = null
  ipv6_ipam_pool_id                    = null
  ipv6_netmask_length                  = null
  ipv6_cidr_block_network_border_group = null

  instance_tenancy = "default"

  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  enable_network_address_usage_metrics = false

  tags = {
    "Name"                     = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# VPC Network ACL
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl
################################################################################

resource "aws_network_acl" "vpc_network_acl" {
  depends_on = [
    aws_vpc.vpc
  ]
  for_each = tomap(local.disaster_recovery)

  vpc_id = aws_vpc.vpc[each.key].id
  region = each.key

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    "Name"                     = "${each.key}-network-acl"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# VPC Subnets
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
# https://www.ipaddressguide.com/cidr
################################################################################

resource "aws_subnet" "vpc_private_subnet_1" {
  depends_on = [
    aws_network_acl.vpc_network_acl
  ]
  for_each = tomap(local.disaster_recovery)

  vpc_id = aws_vpc.vpc[each.key].id
  region = each.key

  cidr_block = cidrsubnet(each.value[0], 4, 0)

  assign_ipv6_address_on_creation = false

  availability_zone_id = each.value[1][0]

  customer_owned_ipv4_pool   = null
  enable_dns64               = false
  enable_lni_at_device_index = null

  enable_resource_name_dns_aaaa_record_on_launch = false
  enable_resource_name_dns_a_record_on_launch    = false

  map_customer_owned_ip_on_launch = null
  map_public_ip_on_launch         = null

  private_dns_hostname_type_on_launch = "ip-name"

  ipv6_cidr_block     = null
  ipv6_native         = false
  ipv4_ipam_pool_id   = null
  ipv4_netmask_length = null
  ipv6_ipam_pool_id   = null
  ipv6_netmask_length = null
  outpost_arn         = null

  tags = {
    "Name"                                  = "${each.key}-private-subnet-1"
    "vpc_id"                                = aws_vpc.vpc[each.key].id
    "vpc_name"                              = "${each.key}-vpc"
    "availability_zone"                     = each.value[2][0]
    "availability_zone_id"                  = each.value[1][0]
    "disaster_recovery_status"              = local.disaster_recovery_status
    "kubernetes.io/role/internal-elb"       = "1"
    "kubernetes.io/cluster/${each.key}-eks" = "owned"
  }
}

resource "aws_subnet" "vpc_private_subnet_2" {
  depends_on = [
    aws_network_acl.vpc_network_acl
  ]
  for_each = tomap(local.disaster_recovery)

  vpc_id = aws_vpc.vpc[each.key].id
  region = each.key

  cidr_block = cidrsubnet(each.value[0], 4, 1)

  availability_zone_id = each.value[1][1]

  customer_owned_ipv4_pool   = null
  enable_dns64               = false
  enable_lni_at_device_index = null

  enable_resource_name_dns_aaaa_record_on_launch = false
  enable_resource_name_dns_a_record_on_launch    = false

  map_customer_owned_ip_on_launch = null
  map_public_ip_on_launch         = null

  private_dns_hostname_type_on_launch = "ip-name"

  ipv6_cidr_block     = null
  ipv6_native         = false
  ipv4_ipam_pool_id   = null
  ipv4_netmask_length = null
  ipv6_ipam_pool_id   = null
  ipv6_netmask_length = null
  outpost_arn         = null

  tags = {
    "Name"                                      = "${each.key}-private-subnet-2"
    "vpc_id"                                    = aws_vpc.vpc[each.key].id
    "vpc_name"                                  = "${each.key}-vpc"
    "availability_zone"                         = each.value[2][1]
    "availability_zone_id"                      = each.value[1][1]
    "disaster_recovery_status"                  = local.disaster_recovery_status
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${local.region}-eks" = "owned"
  }
}

resource "aws_subnet" "vpc_private_subnet_3" {
  depends_on = [
    aws_network_acl.vpc_network_acl
  ]
  for_each = tomap(local.disaster_recovery)

  vpc_id = aws_vpc.vpc[each.key].id
  region = each.key

  cidr_block = cidrsubnet(each.value[0], 4, 2)

  availability_zone_id = each.value[1][2]

  customer_owned_ipv4_pool   = null
  enable_dns64               = false
  enable_lni_at_device_index = null

  enable_resource_name_dns_aaaa_record_on_launch = false
  enable_resource_name_dns_a_record_on_launch    = false

  map_customer_owned_ip_on_launch = null
  map_public_ip_on_launch         = null

  private_dns_hostname_type_on_launch = "ip-name"

  ipv6_cidr_block     = null
  ipv6_native         = false
  ipv4_ipam_pool_id   = null
  ipv4_netmask_length = null
  ipv6_ipam_pool_id   = null
  ipv6_netmask_length = null
  outpost_arn         = null

  tags = {
    "Name"                                      = "${each.key}-private-subnet-3"
    "vpc_id"                                    = aws_vpc.vpc[each.key].id
    "vpc_name"                                  = "${each.key}-vpc"
    "availability_zone"                         = each.value[2][2]
    "availability_zone_id"                      = each.value[1][2]
    "disaster_recovery_status"                  = local.disaster_recovery_status
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${local.region}-eks" = "owned"
  }
}

resource "aws_subnet" "vpc_public_subnet_1" {
  depends_on = [
    aws_network_acl.vpc_network_acl
  ]
  for_each = tomap(local.disaster_recovery)

  vpc_id = aws_vpc.vpc[each.key].id
  region = each.key

  cidr_block = cidrsubnet(each.value[0], 8, 48)

  availability_zone_id = each.value[1][0]

  customer_owned_ipv4_pool   = null
  enable_dns64               = false
  enable_lni_at_device_index = null

  enable_resource_name_dns_aaaa_record_on_launch = false
  enable_resource_name_dns_a_record_on_launch    = false

  map_customer_owned_ip_on_launch = null
  map_public_ip_on_launch         = true

  private_dns_hostname_type_on_launch = "ip-name"

  ipv6_cidr_block     = null
  ipv6_native         = false
  ipv4_ipam_pool_id   = null
  ipv4_netmask_length = null
  ipv6_ipam_pool_id   = null
  ipv6_netmask_length = null
  outpost_arn         = null

  tags = {
    "Name"                                      = "${each.key}-public-subnet-1"
    "vpc_id"                                    = aws_vpc.vpc[each.key].id
    "vpc_name"                                  = "${each.key}-vpc"
    "availability_zone"                         = each.value[2][0]
    "availability_zone_id"                      = each.value[1][0]
    "disaster_recovery_status"                  = local.disaster_recovery_status
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${local.region}-eks" = "owned"
  }
}

resource "aws_subnet" "vpc_public_subnet_2" {
  depends_on = [
    aws_network_acl.vpc_network_acl
  ]
  for_each = tomap(local.disaster_recovery)

  vpc_id = aws_vpc.vpc[each.key].id
  region = each.key

  cidr_block = cidrsubnet(each.value[0], 8, 49)

  availability_zone_id = each.value[1][1]

  customer_owned_ipv4_pool   = null
  enable_dns64               = false
  enable_lni_at_device_index = null

  enable_resource_name_dns_aaaa_record_on_launch = false
  enable_resource_name_dns_a_record_on_launch    = false

  map_customer_owned_ip_on_launch = null
  map_public_ip_on_launch         = true

  private_dns_hostname_type_on_launch = "ip-name"

  ipv6_cidr_block     = null
  ipv6_native         = false
  ipv4_ipam_pool_id   = null
  ipv4_netmask_length = null
  ipv6_ipam_pool_id   = null
  ipv6_netmask_length = null
  outpost_arn         = null

  tags = {
    "Name"                                      = "${each.key}-public-subnet-2"
    "vpc_id"                                    = aws_vpc.vpc[each.key].id
    "vpc_name"                                  = "${each.key}-vpc"
    "availability_zone"                         = each.value[2][1]
    "availability_zone_id"                      = each.value[1][1]
    "disaster_recovery_status"                  = local.disaster_recovery_status
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${local.region}-eks" = "owned"
  }
}

resource "aws_subnet" "vpc_public_subnet_3" {
  depends_on = [
    aws_network_acl.vpc_network_acl
  ]
  for_each = tomap(local.disaster_recovery)

  vpc_id = aws_vpc.vpc[each.key].id
  region = each.key

  cidr_block = cidrsubnet(each.value[0], 8, 50)

  availability_zone_id = each.value[1][2]

  customer_owned_ipv4_pool   = null
  enable_dns64               = false
  enable_lni_at_device_index = null

  enable_resource_name_dns_aaaa_record_on_launch = false
  enable_resource_name_dns_a_record_on_launch    = false

  map_customer_owned_ip_on_launch = null
  map_public_ip_on_launch         = true

  private_dns_hostname_type_on_launch = "ip-name"

  ipv6_cidr_block     = null
  ipv6_native         = false
  ipv4_ipam_pool_id   = null
  ipv4_netmask_length = null
  ipv6_ipam_pool_id   = null
  ipv6_netmask_length = null
  outpost_arn         = null

  tags = {
    "Name"                                      = "${each.key}-public-subnet-3"
    "vpc_id"                                    = aws_vpc.vpc[each.key].id
    "vpc_name"                                  = "${each.key}-vpc"
    "availability_zone"                         = each.value[2][2]
    "availability_zone_id"                      = each.value[1][2]
    "disaster_recovery_status"                  = local.disaster_recovery_status
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${local.region}-eks" = "owned"
  }
}

################################################################################
# VPC Network ACL Association
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_association
################################################################################

resource "aws_network_acl_association" "vpc_network_acl_association_public_1" {
  depends_on = [
    aws_subnet.vpc_public_subnet_1,
    aws_network_acl.vpc_network_acl
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  network_acl_id = aws_network_acl.vpc_network_acl[each.key].id
  subnet_id      = aws_subnet.vpc_public_subnet_1[each.key].id
}

resource "aws_network_acl_association" "vpc_network_acl_association_public_2" {
  depends_on = [
    aws_subnet.vpc_public_subnet_2,
    aws_network_acl.vpc_network_acl
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  network_acl_id = aws_network_acl.vpc_network_acl[each.key].id
  subnet_id      = aws_subnet.vpc_public_subnet_2[each.key].id
}

resource "aws_network_acl_association" "vpc_network_acl_association_public_3" {
  depends_on = [
    aws_subnet.vpc_public_subnet_3,
    aws_network_acl.vpc_network_acl
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  network_acl_id = aws_network_acl.vpc_network_acl[each.key].id
  subnet_id      = aws_subnet.vpc_public_subnet_3[each.key].id
}

resource "aws_network_acl_association" "vpc_network_acl_association_private_1" {
  depends_on = [
    aws_subnet.vpc_private_subnet_1,
    aws_network_acl.vpc_network_acl
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  network_acl_id = aws_network_acl.vpc_network_acl[each.key].id
  subnet_id      = aws_subnet.vpc_private_subnet_1[each.key].id
}

resource "aws_network_acl_association" "vpc_network_acl_association_private_2" {
  depends_on = [
    aws_subnet.vpc_private_subnet_2,
    aws_network_acl.vpc_network_acl
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  network_acl_id = aws_network_acl.vpc_network_acl[each.key].id
  subnet_id      = aws_subnet.vpc_private_subnet_2[each.key].id
}

resource "aws_network_acl_association" "vpc_network_acl_association_private_3" {
  depends_on = [
    aws_subnet.vpc_private_subnet_3,
    aws_network_acl.vpc_network_acl
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  network_acl_id = aws_network_acl.vpc_network_acl[each.key].id
  subnet_id      = aws_subnet.vpc_private_subnet_3[each.key].id
}

################################################################################
# VPC Internet Gateway
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
################################################################################

resource "aws_internet_gateway" "vpc_internet_gateway" {
  depends_on = [
    aws_network_acl_association.vpc_network_acl_association_public_1,
    aws_network_acl_association.vpc_network_acl_association_public_2,
    aws_network_acl_association.vpc_network_acl_association_public_3,
    aws_network_acl_association.vpc_network_acl_association_private_1,
    aws_network_acl_association.vpc_network_acl_association_private_2,
    aws_network_acl_association.vpc_network_acl_association_private_3
  ]
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  tags = {
    "Name"                     = "${each.key}-internet-gateway"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# VPC Internet Gateway Attachment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway_attachment
################################################################################

resource "aws_internet_gateway_attachment" "vpc_internet_gateway_attachment" {
  depends_on = [
    aws_internet_gateway.vpc_internet_gateway
  ]
  for_each            = tomap(local.disaster_recovery)
  region              = each.key
  internet_gateway_id = aws_internet_gateway.vpc_internet_gateway[each.key].id
  vpc_id              = aws_vpc.vpc[each.key].id
}

################################################################################
# VPC NAT Gateway - Elastic IP
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
################################################################################

resource "aws_eip" "vpc_nat_eip" {
  depends_on = [
    aws_internet_gateway_attachment.vpc_internet_gateway_attachment
  ]
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  domain   = "vpc"
  tags = {
    "Name"                     = "${each.key}-nat"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# VPC NAT Gateway
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
################################################################################

resource "aws_nat_gateway" "vpc_nat_gateway" {
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [
    aws_eip.vpc_nat_eip
  ]
  for_each      = tomap(local.disaster_recovery)
  region        = each.key
  allocation_id = aws_eip.vpc_nat_eip[each.key].id
  subnet_id     = aws_subnet.vpc_public_subnet_1[each.key].id
  tags = {
    "Name"                     = "${each.key}-nat-gateway"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# VPC Route Table Public
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
################################################################################

resource "aws_route_table" "vpc_route_table_public" {
  depends_on = [
    aws_nat_gateway.vpc_nat_gateway
  ]
  for_each = tomap(local.disaster_recovery)
  vpc_id   = aws_vpc.vpc[each.key].id
  region   = each.key

  # VPC Range
  route {
    cidr_block = aws_vpc.vpc[each.key].cidr_block
    gateway_id = "local"
  }

  # Remaining Range
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc_internet_gateway[each.key].id
  }

  tags = {
    "Name"                     = "${each.key}-route-table-public"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# VPC Route Table Private
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
################################################################################

resource "aws_route_table" "vpc_route_table_private" {
  depends_on = [
    aws_nat_gateway.vpc_nat_gateway
  ]
  for_each = tomap(local.disaster_recovery)
  vpc_id   = aws_vpc.vpc[each.key].id
  region   = each.key

  # Remaining Range
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.vpc_nat_gateway[each.key].id
  }

  # VPC Range
  route {
    cidr_block = aws_vpc.vpc[each.key].cidr_block
    gateway_id = "local"
  }

  tags = {
    "Name"                     = "${each.key}-route-table-private"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# VPC Route Table Association
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
################################################################################

resource "aws_route_table_association" "vpc_route_table_association_public_1" {
  depends_on = [
    aws_route_table.vpc_route_table_public
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  subnet_id      = aws_subnet.vpc_public_subnet_1[each.key].id
  route_table_id = aws_route_table.vpc_route_table_public[each.key].id
}

resource "aws_route_table_association" "vpc_route_table_association_public_2" {
  depends_on = [
    aws_route_table.vpc_route_table_public
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  subnet_id      = aws_subnet.vpc_public_subnet_2[each.key].id
  route_table_id = aws_route_table.vpc_route_table_public[each.key].id
}

resource "aws_route_table_association" "vpc_route_table_association_public_3" {
  depends_on = [
    aws_route_table.vpc_route_table_public
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  subnet_id      = aws_subnet.vpc_public_subnet_3[each.key].id
  route_table_id = aws_route_table.vpc_route_table_public[each.key].id
}

resource "aws_route_table_association" "vpc_route_table_association_private_1" {
  depends_on = [
    aws_route_table.vpc_route_table_private
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  subnet_id      = aws_subnet.vpc_private_subnet_1[each.key].id
  route_table_id = aws_route_table.vpc_route_table_private[each.key].id
}

resource "aws_route_table_association" "vpc_route_table_association_private_2" {
  depends_on = [
    aws_route_table.vpc_route_table_private
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  subnet_id      = aws_subnet.vpc_private_subnet_2[each.key].id
  route_table_id = aws_route_table.vpc_route_table_private[each.key].id
}

resource "aws_route_table_association" "vpc_route_table_association_private_3" {
  depends_on = [
    aws_route_table.vpc_route_table_private
  ]
  for_each       = tomap(local.disaster_recovery)
  region         = each.key
  subnet_id      = aws_subnet.vpc_private_subnet_3[each.key].id
  route_table_id = aws_route_table.vpc_route_table_private[each.key].id
}

################################################################################
# VPC Endpoint - S3
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint
################################################################################

resource "aws_vpc_endpoint" "s3" {
  depends_on = [
    aws_route_table_association.vpc_route_table_association_private_3
  ]
  for_each          = tomap(local.disaster_recovery)
  region            = each.key
  vpc_id            = aws_vpc.vpc[each.key].id
  service_name      = "com.amazonaws.${each.key}.s3"
  vpc_endpoint_type = "Gateway"
}

################################################################################
# VPC Endpoint - Route Table
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_route_table_association
################################################################################

resource "aws_vpc_endpoint_route_table_association" "s3" {
  depends_on = [
    aws_vpc_endpoint.s3
  ]
  for_each        = tomap(local.disaster_recovery)
  region          = each.key
  route_table_id  = aws_route_table.vpc_route_table_private[each.key].id
  vpc_endpoint_id = aws_vpc_endpoint.s3[each.key].id
}

################################################################################
# VPC Security Groups
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
################################################################################

resource "aws_security_group" "open" {
  depends_on = [
    aws_vpc_endpoint_route_table_association.s3
  ]

  for_each    = tomap(local.disaster_recovery)
  name        = "allow_open_traffic"
  description = "Allow Open Traffic Security Group"
  region      = each.key

  vpc_id = aws_vpc.vpc[each.key].id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name"                     = "allow_open_traffic sg"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_security_group" "ssh" {
  depends_on = [
    aws_security_group.open
  ]

  for_each    = tomap(local.disaster_recovery)
  name        = "allow_ssh"
  description = "Allow SSH Security Group"
  region      = each.key

  vpc_id = aws_vpc.vpc[each.key].id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name"                     = "allow_ssh sg"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_security_group" "http" {
  depends_on = [
    aws_security_group.ssh
  ]

  for_each    = tomap(local.disaster_recovery)
  name        = "allow_http"
  description = "Allow HTTP Security Group"
  region      = each.key

  vpc_id = aws_vpc.vpc[each.key].id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name"                     = "allow_http sg"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_security_group" "http_debug" {
  depends_on = [
    aws_security_group.http
  ]

  for_each    = tomap(local.disaster_recovery)
  name        = "allow_http_debug"
  description = "Allow HTTP 8080 Security Group"
  region      = each.key

  vpc_id = aws_vpc.vpc[each.key].id

  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name"                     = "allow_http_debug sg"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_security_group" "https" {
  depends_on = [
    aws_security_group.http_debug
  ]

  for_each    = tomap(local.disaster_recovery)
  name        = "allow_https"
  description = "Allow HTTPS Security Group"
  region      = each.key

  vpc_id = aws_vpc.vpc[each.key].id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name"                     = "allow_https sg"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_security_group" "ping" {
  depends_on = [
    aws_security_group.https
  ]

  for_each    = tomap(local.disaster_recovery)
  name        = "allow_ping"
  description = "Allow PING Security Group"
  region      = each.key

  vpc_id = aws_vpc.vpc[each.key].id

  ingress {
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name"                     = "allow_ping sg"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_security_group" "api_gateway" {
  depends_on = [
    aws_security_group.ping
  ]

  for_each    = tomap(local.disaster_recovery)
  name        = "allow_api_gateway"
  description = "Allow API Gateway Security Group"
  region      = each.key

  vpc_id = aws_vpc.vpc[each.key].id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name"                     = "allow_api_gateway sg"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_security_group" "loadbalancer" {
  depends_on = [
    aws_security_group.api_gateway
  ]

  for_each    = tomap(local.disaster_recovery)
  name        = "allow_loadbalancer"
  description = "Allow Load Balancer Security Group"
  region      = each.key

  vpc_id = aws_vpc.vpc[each.key].id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name"                     = "allow_loadbalancer sg"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_security_group" "redis" {
  depends_on = [
    aws_security_group.loadbalancer
  ]

  for_each    = tomap(local.disaster_recovery)
  name        = "allow_redis"
  description = "Allow Redis Security Group"
  region      = each.key

  vpc_id = aws_vpc.vpc[each.key].id

  ingress {
    from_port        = 6379
    to_port          = 6379
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name"                     = "allow_redis sg"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_security_group" "efs" {
  depends_on = [
    aws_security_group.loadbalancer
  ]

  for_each    = tomap(local.disaster_recovery)
  name        = "allow_efs"
  description = "Allow EFS Security Group"
  region      = each.key

  vpc_id = aws_vpc.vpc[each.key].id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name"                     = "allow_efs sg"
    "vpc_id"                   = aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# VPC Peering
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection
################################################################################

resource "aws_vpc_peering_connection" "disaster_recovery" {
  depends_on = [
    aws_security_group.redis
  ]

  count = var.disaster_recovery_enabled ? 1 : 0

  # peer_owner_id = var.peer_owner_id
  peer_vpc_id = aws_vpc.vpc["${local.recovery_region}"].id
  peer_region = local.recovery_region
  vpc_id      = aws_vpc.vpc["${local.main_region}"].id
  auto_accept = false

  tags = {
    "Name"                     = "Peering between ${local.main_region} and ${local.recovery_region}"
    "requester"                = aws_vpc.vpc["${local.main_region}"].id
    "accepter"                 = aws_vpc.vpc["${local.recovery_region}"].id
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_vpc_peering_connection_accepter" "disaster_recovery" {
  depends_on = [
    aws_vpc_peering_connection.disaster_recovery
  ]

  count = var.disaster_recovery_enabled ? 1 : 0

  region                    = local.recovery_region
  vpc_peering_connection_id = aws_vpc_peering_connection.disaster_recovery[0].id
  auto_accept               = true

  tags = {
    "Side"                     = "Accepter"
    "Name"                     = "Peering between ${local.main_region} and ${local.recovery_region}"
    "requester"                = aws_vpc.vpc["${local.main_region}"].id
    "accepter"                 = aws_vpc.vpc["${local.recovery_region}"].id
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

resource "aws_vpc_peering_connection_options" "requester" {
  depends_on = [
    aws_vpc_peering_connection_accepter.disaster_recovery
  ]

  count = var.disaster_recovery_enabled ? 1 : 0

  region                    = local.main_region
  vpc_peering_connection_id = aws_vpc_peering_connection.disaster_recovery[0].id
  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "accepter" {
  depends_on = [
    aws_vpc_peering_connection_options.requester
  ]

  count = var.disaster_recovery_enabled ? 1 : 0

  region                    = local.recovery_region
  vpc_peering_connection_id = aws_vpc_peering_connection.disaster_recovery[0].id
  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "null_resource" "disaster_recovery_routes_peering" {
  depends_on = [
    aws_vpc_peering_connection_options.accepter
  ]

  count = var.disaster_recovery_enabled ? 1 : 0

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      aws ec2 create-route --route-table-id ${aws_route_table.vpc_route_table_public[local.main_region].id} --destination-cidr-block ${aws_vpc.vpc[local.recovery_region].cidr_block} --vpc-peering-connection-id ${aws_vpc_peering_connection.disaster_recovery[0].id} --region ${local.main_region}
      aws ec2 create-route --route-table-id ${aws_route_table.vpc_route_table_public[local.recovery_region].id} --destination-cidr-block ${aws_vpc.vpc[local.main_region].cidr_block} --vpc-peering-connection-id ${aws_vpc_peering_connection.disaster_recovery[0].id} --region ${local.recovery_region}
    EOF
  }
}
