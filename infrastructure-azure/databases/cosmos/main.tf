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
# Cosmos Account
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_account
################################################################################

resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "cosmos"
  location            = data.azurerm_resource_group.asia.location
  resource_group_name = data.azurerm_resource_group.asia.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  automatic_failover_enabled = true

  capabilities {
    name = "EnableAggregationPipeline"
  }

  capabilities {
    name = "mongoEnableDocLevelTTL"
  }

  capabilities {
    name = "MongoDBv3.4"
  }

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    location          = data.azurerm_resource_group.europe.location
    failover_priority = 1
  }
}

################################################################################
# Cosmos SQL
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_account
################################################################################

resource "azurerm_cosmosdb_sql_database" "cosmos" {
  name                = "cosmos-sql"
  resource_group_name = azurerm_cosmosdb_account.cosmos.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  throughput          = 400
}

################################################################################
# Cosmos SQL
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_account
################################################################################

resource "azurerm_cosmosdb_sql_container" "cosmos" {
  name                  = "cosmos-container"
  resource_group_name   = azurerm_cosmosdb_account.cosmos.resource_group_name
  account_name          = azurerm_cosmosdb_account.cosmos.name
  database_name         = azurerm_cosmosdb_sql_database.cosmos.name
  partition_key_paths   = ["/definition/id"]
  partition_key_version = 1
  throughput            = 400

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    included_path {
      path = "/included/?"
    }

    excluded_path {
      path = "/excluded/?"
    }
  }

  unique_key {
    paths = ["/definition/idlong", "/definition/idshort"]
  }
}
