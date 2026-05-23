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

data "aws_security_group" "loadbalancer" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_loadbalancer"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

################################################################################
# Network Load Balancer
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
################################################################################

## Game 2048
resource "aws_lb" "game_2048" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "${each.key}-nlb-game-2048"

  internal                   = true
  load_balancer_type         = "network"
  enable_deletion_protection = false
  preserve_host_header       = true

  security_groups = [
    data.aws_security_group.loadbalancer[each.key].id
  ]

  subnets = [
    data.aws_subnet.vpc_private_subnet_1[each.key].id,
    data.aws_subnet.vpc_private_subnet_2[each.key].id,
    data.aws_subnet.vpc_private_subnet_3[each.key].id
  ]

  access_logs {
    bucket  = ""
    prefix  = ""
    enabled = false
  }

  client_keep_alive = null

  connection_logs {
    bucket  = ""
    prefix  = ""
    enabled = false
  }

  customer_owned_ipv4_pool = ""

  desync_mitigation_mode = null

  dns_record_client_routing_policy = "any_availability_zone"
  drop_invalid_header_fields       = null
  enable_cross_zone_load_balancing = false
  enable_http2                     = null

  enable_tls_version_and_cipher_suite_headers = null
  enable_waf_fail_open                        = null
  enable_xff_client_port                      = null
  enable_zonal_shift                          = false

  idle_timeout    = null
  ip_address_type = "ipv4"

  secondary_ips_auto_assigned_per_subnet = 0
  xff_header_processing_mode             = null

  health_check_logs {
    bucket  = ""
    prefix  = ""
    enabled = false
  }

  tags = {
    "Name"                     = "${each.key}-nlb-game-2048"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
    "elbv2.k8s.aws/cluster"    = "${each.key}-vpc"
    "service.k8s.aws/resource" = "LoadBalancer"
  }
}

## Rancher
resource "aws_lb" "rancher" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "${each.key}-nlb-rancher"

  internal                   = true
  load_balancer_type         = "network"
  enable_deletion_protection = false
  preserve_host_header       = true

  security_groups = [
    data.aws_security_group.loadbalancer[each.key].id
  ]

  subnets = [
    data.aws_subnet.vpc_private_subnet_1[each.key].id,
    data.aws_subnet.vpc_private_subnet_2[each.key].id,
    data.aws_subnet.vpc_private_subnet_3[each.key].id
  ]

  access_logs {
    bucket  = ""
    prefix  = ""
    enabled = false
  }

  client_keep_alive = null

  connection_logs {
    bucket  = ""
    prefix  = ""
    enabled = false
  }

  customer_owned_ipv4_pool = ""

  desync_mitigation_mode = null

  dns_record_client_routing_policy = "any_availability_zone"
  drop_invalid_header_fields       = null
  enable_cross_zone_load_balancing = false
  enable_http2                     = null

  enable_tls_version_and_cipher_suite_headers = null
  enable_waf_fail_open                        = null
  enable_xff_client_port                      = null
  enable_zonal_shift                          = false

  idle_timeout    = null
  ip_address_type = "ipv4"

  secondary_ips_auto_assigned_per_subnet = 0
  xff_header_processing_mode             = null

  health_check_logs {
    bucket  = ""
    prefix  = ""
    enabled = false
  }

  tags = {
    "Name"                     = "${each.key}-nlb-rancher"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
    "elbv2.k8s.aws/cluster"    = "${each.key}-vpc"
    "service.k8s.aws/resource" = "LoadBalancer"
  }
}

## Nginx
resource "aws_lb" "nginx" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "${each.key}-nlb-nginx"

  internal                   = true
  load_balancer_type         = "network"
  enable_deletion_protection = false
  preserve_host_header       = true

  security_groups = [
    data.aws_security_group.loadbalancer[each.key].id
  ]

  subnets = [
    data.aws_subnet.vpc_private_subnet_1[each.key].id,
    data.aws_subnet.vpc_private_subnet_2[each.key].id,
    data.aws_subnet.vpc_private_subnet_3[each.key].id
  ]

  access_logs {
    bucket  = ""
    prefix  = ""
    enabled = false
  }

  client_keep_alive = null

  connection_logs {
    bucket  = ""
    prefix  = ""
    enabled = false
  }

  customer_owned_ipv4_pool = ""

  desync_mitigation_mode = null

  dns_record_client_routing_policy = "any_availability_zone"
  drop_invalid_header_fields       = null
  enable_cross_zone_load_balancing = false
  enable_http2                     = null

  enable_tls_version_and_cipher_suite_headers = null
  enable_waf_fail_open                        = null
  enable_xff_client_port                      = null
  enable_zonal_shift                          = false

  idle_timeout    = null
  ip_address_type = "ipv4"

  secondary_ips_auto_assigned_per_subnet = 0
  xff_header_processing_mode             = null

  health_check_logs {
    bucket  = ""
    prefix  = ""
    enabled = false
  }

  tags = {
    "Name"                     = "${each.key}-nlb-nginx"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
    "elbv2.k8s.aws/cluster"    = "${each.key}-vpc"
    "service.k8s.aws/resource" = "LoadBalancer"
  }
}

################################################################################
# Network Load Balancer - Target Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
################################################################################

## Game 2048
resource "aws_lb_target_group" "game_2048" {
  depends_on = [
    aws_lb.game_2048
  ]
  for_each    = tomap(local.disaster_recovery)
  region      = each.key
  name        = "${each.key}-tg-game-2048"
  target_type = "ip"
  port        = 1
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.vpc[each.key].id
  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 10
    timeout             = 10
    unhealthy_threshold = 3
    protocol            = "TCP"
    port                = "traffic-port"
    matcher             = ""
    path                = ""
  }

  # Imports
  connection_termination             = false
  deregistration_delay               = 300
  ip_address_type                    = "ipv4"
  lambda_multi_value_headers_enabled = null
  load_balancing_algorithm_type      = null
  load_balancing_anomaly_mitigation  = null
  load_balancing_cross_zone_enabled  = "use_load_balancer_configuration"
  preserve_client_ip                 = false
  protocol_version                   = null
  proxy_protocol_v2                  = false
  slow_start                         = null
  stickiness {
    enabled         = false
    cookie_duration = 0
    cookie_name     = ""
    type            = "source_ip"
  }

  target_group_health {
    dns_failover {
      minimum_healthy_targets_count      = 1
      minimum_healthy_targets_percentage = "off"
    }
    unhealthy_state_routing {
      minimum_healthy_targets_count      = 1
      minimum_healthy_targets_percentage = "off"
    }
  }
  target_health_state {
    enable_unhealthy_connection_termination = true
    unhealthy_draining_interval             = 0
  }

  tags = {
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
    "elbv2.k8s.aws/cluster"    = "${each.key}-vpc"
  }
}

## Rancher
resource "aws_lb_target_group" "rancher" {
  depends_on = [
    aws_lb.rancher
  ]
  for_each    = tomap(local.disaster_recovery)
  region      = each.key
  name        = "${each.key}-tg-rancher"
  target_type = "ip"
  port        = 1
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.vpc[each.key].id
  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 10
    timeout             = 10
    unhealthy_threshold = 3
    protocol            = "TCP"
    port                = "traffic-port"
    matcher             = ""
    path                = ""
  }

  # Imports
  connection_termination             = false
  deregistration_delay               = 300
  ip_address_type                    = "ipv4"
  lambda_multi_value_headers_enabled = null
  load_balancing_algorithm_type      = null
  load_balancing_anomaly_mitigation  = null
  load_balancing_cross_zone_enabled  = "use_load_balancer_configuration"
  preserve_client_ip                 = false
  protocol_version                   = null
  proxy_protocol_v2                  = false
  slow_start                         = null
  stickiness {
    enabled         = false
    cookie_duration = 0
    cookie_name     = ""
    type            = "source_ip"
  }

  target_group_health {
    dns_failover {
      minimum_healthy_targets_count      = 1
      minimum_healthy_targets_percentage = "off"
    }
    unhealthy_state_routing {
      minimum_healthy_targets_count      = 1
      minimum_healthy_targets_percentage = "off"
    }
  }
  target_health_state {
    enable_unhealthy_connection_termination = true
    unhealthy_draining_interval             = 0
  }

  tags = {
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
    "elbv2.k8s.aws/cluster"    = "${each.key}-vpc"
  }
}

## Nginx
resource "aws_lb_target_group" "nginx" {
  depends_on = [
    aws_lb.nginx
  ]
  for_each    = tomap(local.disaster_recovery)
  region      = each.key
  name        = "${each.key}-tg-nginx"
  target_type = "ip"
  port        = 1
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.vpc[each.key].id
  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 10
    timeout             = 10
    unhealthy_threshold = 3
    protocol            = "TCP"
    port                = "traffic-port"
    matcher             = ""
    path                = ""
  }

  # Imports
  connection_termination             = false
  deregistration_delay               = 300
  ip_address_type                    = "ipv4"
  lambda_multi_value_headers_enabled = null
  load_balancing_algorithm_type      = null
  load_balancing_anomaly_mitigation  = null
  load_balancing_cross_zone_enabled  = "use_load_balancer_configuration"
  preserve_client_ip                 = false
  protocol_version                   = null
  proxy_protocol_v2                  = false
  slow_start                         = null
  stickiness {
    enabled         = false
    cookie_duration = 0
    cookie_name     = ""
    type            = "source_ip"
  }

  target_group_health {
    dns_failover {
      minimum_healthy_targets_count      = 1
      minimum_healthy_targets_percentage = "off"
    }
    unhealthy_state_routing {
      minimum_healthy_targets_count      = 1
      minimum_healthy_targets_percentage = "off"
    }
  }
  target_health_state {
    enable_unhealthy_connection_termination = true
    unhealthy_draining_interval             = 0
  }

  tags = {
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
    "elbv2.k8s.aws/cluster"    = "${each.key}-vpc"
  }
}

################################################################################
# Network Load Balancer - Listener
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
################################################################################

## Game 2048
resource "aws_lb_listener" "game_2048" {
  depends_on = [
    aws_lb_target_group.game_2048
  ]
  for_each          = tomap(local.disaster_recovery)
  region            = each.key
  load_balancer_arn = aws_lb.game_2048[each.key].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.game_2048[each.key].arn
  }

  tags = {
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
    "elbv2.k8s.aws/cluster"    = "${each.key}-vpc"
    "service.k8s.aws/resource" = "80"
  }
}

## Rancher
resource "aws_lb_listener" "rancher" {
  depends_on = [
    aws_lb_target_group.rancher
  ]
  for_each          = tomap(local.disaster_recovery)
  region            = each.key
  load_balancer_arn = aws_lb.rancher[each.key].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rancher[each.key].arn
  }

  tags = {
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
    "elbv2.k8s.aws/cluster"    = "${each.key}-vpc"
    "service.k8s.aws/resource" = "80"
  }
}

## Nginx
resource "aws_lb_listener" "nginx" {
  depends_on = [
    aws_lb_target_group.nginx
  ]
  for_each          = tomap(local.disaster_recovery)
  region            = each.key
  load_balancer_arn = aws_lb.nginx[each.key].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx[each.key].arn
  }

  tags = {
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
    "elbv2.k8s.aws/cluster"    = "${each.key}-vpc"
    "service.k8s.aws/resource" = "80"
  }
}
