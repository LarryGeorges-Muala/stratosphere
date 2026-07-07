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
# Key Vault
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault
################################################################################

resource "azurerm_key_vault" "stratosphere" {
  for_each                    = tomap(local.disaster_recovery)
  name                        = each.key
  location                    = each.key
  resource_group_name         = each.key
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_user_assigned_identity.stratosphere[each.key].tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy = [
    {
      tenant_id      = data.azurerm_user_assigned_identity.stratosphere[each.key].tenant_id
      object_id      = data.azurerm_user_assigned_identity.stratosphere[each.key].principal_id
      application_id = null

      key_permissions = [
        "Get"
      ]

      secret_permissions = [
        "Get",
        "Set"
      ]

      storage_permissions = [
        "Get"
      ]

      certificate_permissions = [
        "Get"
      ]
    },
    {
      tenant_id      = data.azurerm_client_config.current.tenant_id
      object_id      = data.azuread_user.owner.object_id
      application_id = null

      key_permissions = [
        "Backup",
        "Create",
        "Decrypt",
        "Delete",
        "Encrypt",
        "Get",
        "Import",
        "List",
        "Purge",
        "Recover",
        "Restore",
        "Sign",
        "UnwrapKey",
        "Update",
        "Verify",
        "WrapKey",
        "Release",
        "Rotate",
        "GetRotationPolicy",
        "SetRotationPolicy"
      ]

      secret_permissions = [
        "Backup",
        "Delete",
        "Get",
        "List",
        "Purge",
        "Recover",
        "Restore",
        "Set"
      ]

      storage_permissions = [
        "Backup",
        "Delete",
        "DeleteSAS",
        "Get",
        "GetSAS",
        "List",
        "ListSAS",
        "Purge",
        "Recover",
        "RegenerateKey",
        "Restore",
        "Set",
        "SetSAS",
        "Update"
      ]

      certificate_permissions = [
        "Backup",
        "Create",
        "Delete",
        "DeleteIssuers",
        "Get",
        "GetIssuers",
        "Import",
        "List",
        "ListIssuers",
        "ManageContacts",
        "ManageIssuers",
        "Purge",
        "Recover",
        "Restore",
        "SetIssuers",
        "Update"
      ]
    },
    {
      tenant_id      = data.azurerm_client_config.current.tenant_id
      object_id      = data.azuread_user.devops.object_id
      application_id = null

      key_permissions = [
        "Backup",
        "Create",
        "Decrypt",
        "Delete",
        "Encrypt",
        "Get",
        "Import",
        "List",
        "Purge",
        "Recover",
        "Restore",
        "Sign",
        "UnwrapKey",
        "Update",
        "Verify",
        "WrapKey",
        "Release",
        "Rotate",
        "GetRotationPolicy",
        "SetRotationPolicy"
      ]

      secret_permissions = [
        "Backup",
        "Delete",
        "Get",
        "List",
        "Purge",
        "Recover",
        "Restore",
        "Set"
      ]

      storage_permissions = [
        "Backup",
        "Delete",
        "DeleteSAS",
        "Get",
        "GetSAS",
        "List",
        "ListSAS",
        "Purge",
        "Recover",
        "RegenerateKey",
        "Restore",
        "Set",
        "SetSAS",
        "Update"
      ]

      certificate_permissions = [
        "Backup",
        "Create",
        "Delete",
        "DeleteIssuers",
        "Get",
        "GetIssuers",
        "Import",
        "List",
        "ListIssuers",
        "ManageContacts",
        "ManageIssuers",
        "Purge",
        "Recover",
        "Restore",
        "SetIssuers",
        "Update"
      ]
    }
  ]
}

################################################################################
# Role Assignment
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
################################################################################

resource "azurerm_role_assignment" "key_reader" {
  depends_on = [
    azurerm_key_vault.stratosphere
  ]
  for_each             = tomap(local.disaster_recovery)
  scope                = azurerm_key_vault.stratosphere[each.key].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_user_assigned_identity.stratosphere[each.key].principal_id
}
