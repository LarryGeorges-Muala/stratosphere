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
# Data - Client Config
# https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config
################################################################################

data "azuread_client_config" "current" {}

################################################################################
# AD App
# https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application
################################################################################

resource "azuread_application" "stratosphere" {
  display_name = "stratosphere"
  owners       = [data.azuread_client_config.current.object_id]
}

################################################################################
# Service Principal
# https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal
################################################################################

resource "azuread_service_principal" "stratosphere" {
  depends_on = [
    azuread_application.stratosphere
  ]
  client_id                    = azuread_application.stratosphere.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
  account_enabled              = true
  description                  = "Stratosphere control service principal"
  alternative_names = [
    "stratosphere"
  ]
}

################################################################################
# User Assigned Identity
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity
################################################################################

resource "azurerm_user_assigned_identity" "stratosphere" {
  depends_on = [
    azuread_service_principal.stratosphere
  ]
  for_each            = tomap(local.disaster_recovery)
  resource_group_name = each.key
  location            = each.key
  name                = each.key
  isolation_scope     = "Regional"
}

################################################################################
# OIDC
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
################################################################################

resource "azurerm_federated_identity_credential" "stratosphere_github_repo_main" {
  depends_on = [
    azurerm_user_assigned_identity.stratosphere
  ]
  for_each                  = tomap(local.disaster_recovery)
  name                      = "${each.key}-github-stratosphere-repo-main"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.stratosphere[each.key].id
  subject                   = "repo:LarryGeorges-Muala/stratosphere:ref:refs/heads/main"
}
