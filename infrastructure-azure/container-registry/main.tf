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
# Data - UAI
# https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/application
################################################################################

data "azurerm_user_assigned_identity" "stratosphere" {
  for_each            = tomap(local.disaster_recovery)
  name                = each.key
  resource_group_name = each.key
}

################################################################################
# Container Registry
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry
################################################################################

resource "azurerm_container_registry" "stratosphere" {
  for_each                      = tomap(local.disaster_recovery)
  name                          = "${each.key}Stratosphere"
  resource_group_name           = each.key
  location                      = each.key
  sku                           = "Basic"
  admin_enabled                 = true
  public_network_access_enabled = true

  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.stratosphere[each.key].id
    ]
  }

  # georeplications {
  #   location                = "${each.value[0]}"
  #   zone_redundancy_enabled = true
  #   tags                    = {}
  # }

}

################################################################################
# Role Assignment
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
################################################################################

resource "azurerm_role_assignment" "writer" {
  depends_on = [
    azurerm_container_registry.stratosphere
  ]
  for_each             = tomap(local.disaster_recovery)
  scope                = azurerm_container_registry.stratosphere[each.key].id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_user_assigned_identity.stratosphere[each.key].principal_id
}

resource "azurerm_role_assignment" "reader" {
  depends_on = [
    azurerm_role_assignment.writer
  ]
  for_each             = tomap(local.disaster_recovery)
  scope                = azurerm_container_registry.stratosphere[each.key].id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_user_assigned_identity.stratosphere[each.key].principal_id
}
