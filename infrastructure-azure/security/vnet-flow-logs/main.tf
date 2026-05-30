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
  name     = local.main_region
}

data "azurerm_resource_group" "europe" {
  name     = local.recovery_region
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
# Data - Network Watcher
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/network_watcher
################################################################################

data "azurerm_network_watcher" "watcher" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-network-watcher"
  resource_group_name = each.key
}

################################################################################
# VNET Flow Logs - Storage
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
################################################################################

resource "azurerm_storage_account" "vnet_flow_logs" {
  for_each                 = tomap(local.disaster_recovery)
  name                = "${each.key}-flow-logs"
  resource_group_name = each.key
  location            = each.key
  account_tier               = "Standard"
  account_kind               = "StorageV2"
  account_replication_type   = "LRS"
  https_traffic_only_enabled = true
}

################################################################################
# VNET Flow Logs - Workspace
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
################################################################################

resource "azurerm_log_analytics_workspace" "vnet_flow_logs" {
  depends_on = [
    azurerm_storage_account.vnet_flow_logs
  ]
  for_each                 = tomap(local.disaster_recovery)
  name                = "${each.key}-workspace-flow-logs"
  location            = each.key
  resource_group_name = each.key
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

################################################################################
# VNET Flow Logs
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_watcher_flow_log
################################################################################

resource "azurerm_network_watcher_flow_log" "vnet_flow_logs" {
  depends_on = [
    azurerm_log_analytics_workspace.vnet_flow_logs
  ]
  for_each                 = tomap(local.disaster_recovery)
  network_watcher_name = data.azurerm_network_watcher.watcher[each.key].name
  resource_group_name  = each.key
  location  = each.key
  name                 = "${each.key}-vnet-flow-logs"

  target_resource_id = data.azurerm_virtual_network.vnet[each.key].id
  storage_account_id = azurerm_storage_account.vnet_flow_logs[each.key].id
  enabled            = true

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.vnet_flow_logs[each.key].workspace_id
    workspace_region      = azurerm_log_analytics_workspace.vnet_flow_logs[each.key].location
    workspace_resource_id = azurerm_log_analytics_workspace.vnet_flow_logs[each.key].id
    interval_in_minutes   = 10
  }
}
