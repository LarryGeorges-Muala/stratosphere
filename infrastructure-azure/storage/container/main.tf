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
# Data - Storage Account
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account
################################################################################

data "azurerm_storage_account" "stratosphere" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}stratos"
  resource_group_name = each.key
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
# Subnets
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
################################################################################

resource "azurerm_subnet" "container" {
  for_each             = tomap(local.disaster_recovery)
  name                 = "${each.key}-container-subnet"
  resource_group_name  = each.key
  virtual_network_name = data.azurerm_virtual_network.vnet[each.key].name
  address_prefixes = [
    cidrsubnet(data.azurerm_virtual_network.vnet[each.key].address_space[0], 4, 4)
  ]
  service_endpoints = ["Microsoft.Storage"]
}

################################################################################
# Storage Network Rules
# https://registry.terraform.io/providers/hashicorp/Azurerm/latest/docs/resources/storage_account_network_rules
################################################################################

resource "azurerm_storage_account_network_rules" "container" {
  depends_on = [
    azurerm_subnet.container
  ]
  for_each           = tomap(local.disaster_recovery)
  storage_account_id = data.azurerm_storage_account.stratosphere[each.key].id
  # default_action             = "Deny"
  default_action             = "Allow"
  virtual_network_subnet_ids = [azurerm_subnet.container[each.key].id]
  # bypass                     = ["Metrics", "Logging", "AzureServices"]
}


################################################################################
# Storage Container
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container
################################################################################

resource "azurerm_storage_container" "container" {
  depends_on = [
    azurerm_storage_account_network_rules.container
  ]
  for_each              = tomap(local.disaster_recovery)
  name                  = "${each.key}-container-account"
  storage_account_id    = data.azurerm_storage_account.stratosphere[each.key].id
  container_access_type = "private"
}

################################################################################
# Storage Replication
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_object_replication
################################################################################

resource "azurerm_storage_object_replication" "container_main" {
  depends_on = [
    azurerm_storage_container.container
  ]
  count                          = var.disaster_recovery_enabled ? 1 : 0
  source_storage_account_id      = data.azurerm_storage_account.stratosphere[local.main_region].id
  destination_storage_account_id = data.azurerm_storage_account.stratosphere[local.recovery_region].id
  rules {
    source_container_name      = azurerm_storage_container.container[local.main_region].name
    destination_container_name = azurerm_storage_container.container[local.recovery_region].name
  }
}

resource "azurerm_storage_object_replication" "container_recovery" {
  depends_on = [
    azurerm_storage_object_replication.container_main
  ]
  count                          = var.disaster_recovery_enabled ? 1 : 0
  source_storage_account_id      = data.azurerm_storage_account.stratosphere[local.recovery_region].id
  destination_storage_account_id = data.azurerm_storage_account.stratosphere[local.main_region].id
  rules {
    source_container_name      = azurerm_storage_container.container[local.recovery_region].name
    destination_container_name = azurerm_storage_container.container[local.main_region].name
  }
}
