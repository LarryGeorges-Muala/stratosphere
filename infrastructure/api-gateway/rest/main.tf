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

  region = each.key

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

################################################################################
# Data - Security Groups
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group
################################################################################

data "aws_security_group" "api_gateway" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "allow_api_gateway"
  vpc_id   = data.aws_vpc.vpc[each.key].id
}

################################################################################
# Data - NLB
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb
################################################################################

## GAME 2048
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

## RANCHER
data "aws_lb" "rancher" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  tags = {
    "Name"                  = "${each.key}-nlb-rancher"
    "vpc_id"                = data.aws_vpc.vpc[each.key].id
    "vpc_name"              = "${each.key}-vpc"
    "elbv2.k8s.aws/cluster" = "${each.key}-vpc"
  }
}

################################################################################
# Data - NLB Listener
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_listener
################################################################################

## GAME 2048
data "aws_lb_listener" "game_2048" {
  for_each          = tomap(local.disaster_recovery)
  region            = each.key
  load_balancer_arn = data.aws_lb.game_2048[each.key].arn
  port              = 80
}

## RANCHER
data "aws_lb_listener" "rancher" {
  for_each          = tomap(local.disaster_recovery)
  region            = each.key
  load_balancer_arn = data.aws_lb.rancher[each.key].arn
  port              = 80
}

################################################################################
# API GATEWAY - VPC Link
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_vpc_link
################################################################################

resource "aws_apigatewayv2_vpc_link" "vpc_link" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "${each.key}-vpc-link"
  security_group_ids = [
    data.aws_security_group.api_gateway[each.key].id
  ]
  subnet_ids = [
    data.aws_subnet.vpc_private_subnet_1[each.key].id,
    data.aws_subnet.vpc_private_subnet_2[each.key].id,
    data.aws_subnet.vpc_private_subnet_3[each.key].id
  ]
  tags = {
    "Name"                     = "${each.key}-vpc-link"
    "vpc_id"                   = data.aws_vpc.vpc[each.key].id
    "vpc_name"                 = "${each.key}-vpc"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# API GATEWAY - Rest API
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api
################################################################################

resource "aws_api_gateway_rest_api" "rest_api" {
  depends_on = [
    aws_apigatewayv2_vpc_link.vpc_link
  ]
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  name     = "${each.key}-rest-api"
  endpoint_configuration {
    ip_address_type = "ipv4"
    types = [
      "EDGE"
    ]
  }
  tags = {
    "Name"                     = "${each.key}-rest-api"
    "api_gateway"              = "${each.key}-rest-api"
    "type"                     = "EDGE"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# API GATEWAY - Rest API Resource
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource
################################################################################

## GAME 2048
resource "aws_api_gateway_resource" "game_2048" {
  depends_on = [
    aws_api_gateway_rest_api.rest_api
  ]
  for_each    = tomap(local.disaster_recovery)
  region      = each.key
  rest_api_id = aws_api_gateway_rest_api.rest_api[each.key].id
  parent_id   = aws_api_gateway_rest_api.rest_api[each.key].root_resource_id
  path_part   = "game"
}

## RANCHER
resource "aws_api_gateway_resource" "rancher" {
  depends_on = [
    aws_api_gateway_rest_api.rest_api
  ]
  for_each    = tomap(local.disaster_recovery)
  region      = each.key
  rest_api_id = aws_api_gateway_rest_api.rest_api[each.key].id
  parent_id   = aws_api_gateway_rest_api.rest_api[each.key].root_resource_id
  path_part   = "rancher"
}

################################################################################
# API GATEWAY - Rest API Method
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method
################################################################################

## GAME 2048
resource "aws_api_gateway_method" "game_2048" {
  depends_on = [
    aws_api_gateway_resource.game_2048
  ]
  for_each      = tomap(local.disaster_recovery)
  region        = each.key
  rest_api_id   = aws_api_gateway_rest_api.rest_api[each.key].id
  resource_id   = aws_api_gateway_resource.game_2048[each.key].id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

## RANCHER
resource "aws_api_gateway_method" "rancher" {
  depends_on = [
    aws_api_gateway_resource.rancher
  ]
  for_each      = tomap(local.disaster_recovery)
  region        = each.key
  rest_api_id   = aws_api_gateway_rest_api.rest_api[each.key].id
  resource_id   = aws_api_gateway_resource.rancher[each.key].id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

################################################################################
# API GATEWAY - Rest API Integration
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration
################################################################################

## GAME 2048
resource "aws_api_gateway_integration" "game_2048" {
  depends_on = [
    aws_api_gateway_method.game_2048
  ]
  for_each                = tomap(local.disaster_recovery)
  region                  = each.key
  rest_api_id             = aws_api_gateway_rest_api.rest_api[each.key].id
  resource_id             = aws_api_gateway_resource.game_2048[each.key].id
  http_method             = aws_api_gateway_method.game_2048[each.key].http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_apigatewayv2_vpc_link.vpc_link[each.key].id
  integration_target      = data.aws_lb.game_2048[each.key].arn
  uri                     = "http://${data.aws_lb.game_2048[each.key].dns_name}"
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

## RANCHER
resource "aws_api_gateway_integration" "rancher" {
  depends_on = [
    aws_api_gateway_method.rancher
  ]
  for_each                = tomap(local.disaster_recovery)
  region                  = each.key
  rest_api_id             = aws_api_gateway_rest_api.rest_api[each.key].id
  resource_id             = aws_api_gateway_resource.rancher[each.key].id
  http_method             = aws_api_gateway_method.rancher[each.key].http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_apigatewayv2_vpc_link.vpc_link[each.key].id
  integration_target      = data.aws_lb.rancher[each.key].arn
  uri                     = "http://${data.aws_lb.rancher[each.key].dns_name}"
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

################################################################################
# API GATEWAY - Rest API Deployment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment
################################################################################

## GAME 2048
resource "aws_api_gateway_deployment" "game_2048" {
  depends_on = [
    aws_api_gateway_integration.game_2048
  ]
  for_each    = tomap(local.disaster_recovery)
  region      = each.key
  rest_api_id = aws_api_gateway_rest_api.rest_api[each.key].id
  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.game_2048[each.key].id,
      aws_api_gateway_method.game_2048[each.key].id,
      aws_api_gateway_integration.game_2048[each.key].id,
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

## RANCHER
resource "aws_api_gateway_deployment" "rancher" {
  depends_on = [
    aws_api_gateway_integration.rancher
  ]
  for_each    = tomap(local.disaster_recovery)
  region      = each.key
  rest_api_id = aws_api_gateway_rest_api.rest_api[each.key].id
  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.rancher[each.key].id,
      aws_api_gateway_method.rancher[each.key].id,
      aws_api_gateway_integration.rancher[each.key].id,
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# API GATEWAY - Rest API Stage
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage
################################################################################

## GAME 2048
resource "aws_api_gateway_stage" "game_2048" {
  depends_on = [
    aws_api_gateway_deployment.game_2048
  ]
  for_each      = tomap(local.disaster_recovery)
  region        = each.key
  deployment_id = aws_api_gateway_deployment.game_2048[each.key].id
  rest_api_id   = aws_api_gateway_rest_api.rest_api[each.key].id
  stage_name    = "staging"
  tags = {
    "Name"                     = "staging"
    "api_gateway"              = "${each.key}-rest-api"
    "type"                     = "EDGE"
    "application"              = "Game 2048"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

## RANCHER
resource "aws_api_gateway_stage" "rancher" {
  depends_on = [
    aws_api_gateway_deployment.rancher
  ]
  for_each      = tomap(local.disaster_recovery)
  region        = each.key
  deployment_id = aws_api_gateway_deployment.rancher[each.key].id
  rest_api_id   = aws_api_gateway_rest_api.rest_api[each.key].id
  stage_name    = "cluster"
  tags = {
    "Name"                     = "cluster"
    "api_gateway"              = "${each.key}-rest-api"
    "type"                     = "EDGE"
    "application"              = "Rancher"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}
