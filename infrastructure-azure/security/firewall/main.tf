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
# Data - Network Watcher
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/network_watcher
################################################################################

data "azurerm_network_watcher" "watcher" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-network-watcher"
  resource_group_name = each.key
}

################################################################################
# Subnets
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
################################################################################

resource "azurerm_subnet" "firewall" {
  for_each             = tomap(local.disaster_recovery)
  name                 = "AzureFirewallSubnet"
  resource_group_name  = each.key
  virtual_network_name = data.azurerm_virtual_network.vnet[each.key].name
  address_prefixes = [
    cidrsubnet(data.azurerm_virtual_network.vnet[each.key].address_space[0], 8, 0)
  ]
  default_outbound_access_enabled = true
}

################################################################################
# Firewall - Public IP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
################################################################################

resource "azurerm_public_ip" "firewall" {
  depends_on = [
    azurerm_subnet.firewall
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-ip-firewall"
  resource_group_name = each.key
  location            = each.key
  allocation_method   = "Static"
  sku                 = "Standard"
}

################################################################################
# Firewall
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall
################################################################################

resource "azurerm_firewall" "firewall" {
  depends_on = [
    azurerm_public_ip.firewall
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-firewall"
  location            = each.key
  resource_group_name = each.key
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall[each.key].id
    public_ip_address_id = azurerm_public_ip.firewall[each.key].id
  }
}

################################################################################
# Route Table
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table
################################################################################

resource "azurerm_route_table" "firewall" {
  depends_on = [
    azurerm_firewall.firewall
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-firewall-route"
  location            = each.key
  resource_group_name = each.key

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.firewall[each.key].ip_configuration[0].private_ip_address
  }
}
