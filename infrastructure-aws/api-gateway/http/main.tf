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

## NGINX
data "aws_lb" "nginx" {
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  tags = {
    "Name"                  = "${each.key}-nlb-nginx"
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

## NGINX
data "aws_lb_listener" "nginx" {
  for_each          = tomap(local.disaster_recovery)
  region            = each.key
  load_balancer_arn = data.aws_lb.nginx[each.key].arn
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
# API GATEWAY - HTTP API
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api
################################################################################

resource "aws_apigatewayv2_api" "http_api" {
  depends_on = [
    aws_apigatewayv2_vpc_link.vpc_link
  ]
  for_each      = tomap(local.disaster_recovery)
  region        = each.key
  name          = "${each.key}-http-api"
  protocol_type = "HTTP"
  tags = {
    "Name"                     = "${each.key}-http-api"
    "api_gateway"              = "${each.key}-http-api"
    "type"                     = "Regional"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# API GATEWAY - HTTP API Integration
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration
################################################################################

## GAME 2048
resource "aws_apigatewayv2_integration" "game_2048" {
  depends_on = [
    aws_apigatewayv2_api.http_api
  ]
  for_each = tomap(local.disaster_recovery)
  region   = each.key
  api_id   = aws_apigatewayv2_api.http_api[each.key].id
  # credentials_arn  = aws_iam_role.example.arn
  description      = "GAME 2048 NLB"
  integration_type = "HTTP_PROXY"
  integration_uri  = data.aws_lb_listener.game_2048[each.key].arn

  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.vpc_link[each.key].id

  # tls_config {
  #   server_name_to_verify = "example.com"
  # }

  # request_parameters = {
  #   "append:header.authforintegration" = "$context.authorizer.authorizerResponse"
  #   "overwrite:path"                   = "staticValueForIntegration"
  # }

  # response_parameters {
  #   status_code = 403
  #   mappings = {
  #     "append:header.auth" = "$context.authorizer.authorizerResponse"
  #   }
  # }

  # response_parameters {
  #   status_code = 200
  #   mappings = {
  #     "overwrite:statuscode" = "204"
  #   }
  # }
}

## NGINX
resource "aws_apigatewayv2_integration" "nginx" {
  depends_on = [
    aws_apigatewayv2_api.http_api
  ]
  for_each         = tomap(local.disaster_recovery)
  region           = each.key
  api_id           = aws_apigatewayv2_api.http_api[each.key].id
  description      = "NGINX NLB"
  integration_type = "HTTP_PROXY"
  integration_uri  = data.aws_lb_listener.nginx[each.key].arn

  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.vpc_link[each.key].id

  # tls_config {
  #   server_name_to_verify = "example.com"
  # }
}

################################################################################
# API GATEWAY - HTTP API Route
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route
################################################################################

## GAME 2048
resource "aws_apigatewayv2_route" "game_2048" {
  depends_on = [
    aws_apigatewayv2_integration.game_2048
  ]
  for_each  = tomap(local.disaster_recovery)
  region    = each.key
  api_id    = aws_apigatewayv2_api.http_api[each.key].id
  # route_key = "GET /{proxy+}"
  route_key = "$default"

  target = "integrations/${aws_apigatewayv2_integration.game_2048[each.key].id}"
}

## NGINX
resource "aws_apigatewayv2_route" "nginx" {
  depends_on = [
    aws_apigatewayv2_integration.nginx
  ]
  for_each  = tomap(local.disaster_recovery)
  region    = each.key
  api_id    = aws_apigatewayv2_api.http_api[each.key].id
  route_key = "GET /api"

  target = "integrations/${aws_apigatewayv2_integration.nginx[each.key].id}"
}

resource "aws_apigatewayv2_route" "nginx_trailing" {
  depends_on = [
    aws_apigatewayv2_integration.nginx
  ]
  for_each  = tomap(local.disaster_recovery)
  region    = aws_apigatewayv2_route.nginx[each.key].region
  api_id    = aws_apigatewayv2_route.nginx[each.key].api_id
  route_key = "${aws_apigatewayv2_route.nginx[each.key].route_key}/{proxy+}"
  target = aws_apigatewayv2_route.nginx[each.key].target
}

################################################################################
# API GATEWAY - HTTP API Deployment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_deployment
################################################################################

resource "aws_apigatewayv2_deployment" "http_api" {
  depends_on = [
    aws_apigatewayv2_route.game_2048,
    aws_apigatewayv2_route.nginx,
    aws_apigatewayv2_route.nginx_trailing
  ]
  for_each    = tomap(local.disaster_recovery)
  region      = each.key
  api_id      = aws_apigatewayv2_api.http_api[each.key].id
  description = "${each.key}-http-api deployment"

  triggers = {
    redeployment = sha1(join(",", tolist([
      jsonencode(aws_apigatewayv2_integration.game_2048[each.key]),
      jsonencode(aws_apigatewayv2_route.game_2048[each.key]),
      jsonencode(aws_apigatewayv2_integration.nginx[each.key]),
      jsonencode(aws_apigatewayv2_route.nginx[each.key]),
      jsonencode(aws_apigatewayv2_route.nginx_trailing[each.key]),
    ])))
  }

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# API GATEWAY - HTTP API Stage
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage
################################################################################

resource "aws_apigatewayv2_stage" "http_api" {
  depends_on = [
    aws_apigatewayv2_deployment.http_api
  ]
  for_each      = tomap(local.disaster_recovery)
  region        = each.key
  api_id        = aws_apigatewayv2_api.http_api[each.key].id
  name          = "$default"
  deployment_id = aws_apigatewayv2_deployment.http_api[each.key].id
  # route_settings {
  #   route_key = aws_apigatewayv2_route.game_2048[each.key].route_key
  # }
  tags = {
    "Name"                     = "default"
    "api_gateway"              = "${each.key}-http-api"
    "type"                     = "Regional"
    "application"              = "Game 2048 / Nginx"
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}
