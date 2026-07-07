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
  main_region     = "southeastasia"
  recovery_region = "westeurope"

  region = local.main_region

  main_region_setup = {
    "${local.main_region}" = [
      "${local.recovery_region}"
    ]
  }

  main_and_recovery_region_setup = {
    "${local.main_region}" = [
      "${local.recovery_region}"
    ]
    "${local.recovery_region}" = [
      "${local.main_region}"
    ]
  }

  disaster_recovery = var.disaster_recovery_enabled == true ? local.main_and_recovery_region_setup : local.main_region_setup

  disaster_recovery_status = var.disaster_recovery_enabled == true ? "multi-region setup active" : "single-region setup active"

  tags = {
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# Data - Resource Group
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group
################################################################################

data "azurerm_resource_group" "asia" {
  name = local.main_region
}

data "azurerm_resource_group" "europe" {
  name = local.recovery_region
}

################################################################################
# Data - VNET
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network
################################################################################

data "azurerm_virtual_network" "vnet" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-vnet"
  resource_group_name = each.key
}

################################################################################
# Data - VNET Network Security Group
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/network_security_group
################################################################################

data "azurerm_network_security_group" "nacl" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-sg-nacl"
  resource_group_name = each.key
}

################################################################################
# Data - Subnets
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet
################################################################################

data "azurerm_subnet" "private" {
  for_each             = tomap(local.disaster_recovery)
  name                 = "${each.key}-vnet-subnet-private"
  virtual_network_name = data.azurerm_virtual_network.vnet[each.key].name
  resource_group_name  = each.key
}

data "azurerm_subnet" "public" {
  for_each             = tomap(local.disaster_recovery)
  name                 = "${each.key}-vnet-subnet-public"
  virtual_network_name = data.azurerm_virtual_network.vnet[each.key].name
  resource_group_name  = each.key
}

################################################################################
# Data - Service Principal
# https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principal
################################################################################

data "azuread_service_principal" "stratosphere" {
  display_name = "stratosphere"
}

################################################################################
# Data - AD App
# https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/application
################################################################################

data "azuread_application" "stratosphere" {
  display_name = "stratosphere"
}

################################################################################
# Data - UAI
# https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/application
################################################################################

data "azurerm_user_assigned_identity" "stratosphere" {
  for_each            = tomap(local.disaster_recovery)
  name                = each.key
  resource_group_name = each.key
}

################################################################################
# Service Plan
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan
################################################################################

resource "azurerm_service_plan" "app_service" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-service-plan"
  resource_group_name = each.key
  location            = each.key
  os_type             = "Linux"
  sku_name            = "F1"
}

################################################################################
# App Service
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app
################################################################################

resource "azurerm_linux_web_app" "node" {
  depends_on = [
    azurerm_service_plan.app_service
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-node"
  resource_group_name = each.key
  location            = each.key
  service_plan_id     = azurerm_service_plan.app_service[each.key].id

  enabled                       = true
  https_only                    = true
  public_network_access_enabled = true
  # virtual_network_subnet_id = data.azurerm_subnet.public[each.key].id
  # vnet_image_pull_enabled = false

  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.stratosphere[each.key].id
    ]
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    application_logs {
      file_system_level = "Verbose" # Options: Verbose, Information, Warning, Error, Off
    }

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  site_config {
    always_on = false # always_on must be explicitly set to false when using Free, F1, D1, or Shared Service Plans.
    application_stack {
      node_version = "22-lts"
    }
  }
}

resource "azurerm_linux_web_app" "docker" {
  depends_on = [
    azurerm_linux_web_app.node
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-docker"
  resource_group_name = each.key
  location            = each.key
  service_plan_id     = azurerm_service_plan.app_service[each.key].id

  enabled                       = true
  https_only                    = true
  public_network_access_enabled = true

  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.stratosphere[each.key].id
    ]
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    application_logs {
      file_system_level = "Verbose" # Options: Verbose, Information, Warning, Error, Off
    }

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  site_config {
    always_on                                     = false # always_on must be explicitly set to false when using Free, F1, D1, or Shared Service Plans.
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = data.azurerm_user_assigned_identity.stratosphere[each.key].client_id
    application_stack {
      docker_image_name = "nginx:alpine"
    }
  }
}

################################################################################
# Role Assignment
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
################################################################################

resource "azurerm_role_assignment" "node" {
  depends_on = [
    azurerm_linux_web_app.docker
  ]
  for_each             = tomap(local.disaster_recovery)
  scope                = azurerm_linux_web_app.node[each.key].id
  role_definition_name = "Website Contributor"
  principal_id         = data.azurerm_user_assigned_identity.stratosphere[each.key].principal_id
}

resource "azurerm_role_assignment" "docker" {
  depends_on = [
    azurerm_role_assignment.node
  ]
  for_each             = tomap(local.disaster_recovery)
  scope                = azurerm_linux_web_app.docker[each.key].id
  role_definition_name = "Website Contributor"
  principal_id         = data.azurerm_user_assigned_identity.stratosphere[each.key].principal_id
}
