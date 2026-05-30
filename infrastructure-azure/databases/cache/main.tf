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
# Managed Redis
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_redis
################################################################################

resource "azurerm_managed_redis" "cache" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-cache"
  resource_group_name = each.key
  location            = each.key

  sku_name = "Balanced_B3"

  default_database {
    geo_replication_group_name = "geo-cache"
  }
}

################################################################################
# Replication
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_redis_geo_replication
################################################################################

resource "azurerm_managed_redis_geo_replication" "cache" {
  managed_redis_id = azurerm_managed_redis.cache[local.main_region].id

  linked_managed_redis_ids = [
    azurerm_managed_redis.cache[local.recovery_region].id,
  ]
}
