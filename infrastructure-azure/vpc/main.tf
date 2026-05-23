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

  main_vpc_cidr_block     = "10.0.0.0/16"
  recovery_vpc_cidr_block = "172.16.0.0/16"

  main_region_setup = {
    "${local.main_region}" = [
      "${local.main_vpc_cidr_block}"
    ]
  }

  main_and_recovery_region_setup = {
    "${local.main_region}" = [
      "${local.main_vpc_cidr_block}"
    ]
    "${local.recovery_region}" = [
      "${local.recovery_vpc_cidr_block}"
    ]
  }

  disaster_recovery = var.disaster_recovery_enabled == true ? local.main_and_recovery_region_setup : local.main_region_setup

  disaster_recovery_status = var.disaster_recovery_enabled == true ? "multi-region setup active" : "single-region setup active"

  tags = {
    "disaster_recovery_status" = local.disaster_recovery_status
  }
}

################################################################################
# VNET Regions
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
################################################################################

resource "azurerm_resource_group" "asia" {
  name     = "southeastasia"
  location = "Southeast Asia"
}

resource "azurerm_resource_group" "europe" {
  name     = "westeurope"
  location = "West Europe"
}

################################################################################
# VNET
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network
################################################################################

resource "azurerm_virtual_network" "vnet" {
  depends_on = [
    azurerm_resource_group.asia,
    azurerm_resource_group.europe
  ]
  for_each = tomap(local.disaster_recovery)
  name     = "${each.key}-vnet"
  address_space = [
    each.value[0]
  ]
  location            = each.key
  resource_group_name = each.key

  tags = local.tags
}

################################################################################
# VNET Network Security Group
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group
################################################################################

resource "azurerm_network_security_group" "nacl" {
  depends_on = [
    azurerm_virtual_network.vnet
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-sg-nacl"
  location            = each.key
  resource_group_name = each.key

  security_rule {
    name                       = "${each.key}-sg-nacl-ingress-tcp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "${each.key}-sg-nacl-egress-tcp"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "${each.key}-sg-nacl-ingress-icmp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "${each.key}-sg-nacl-egress-icmp"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.tags
}

################################################################################
# Subnets
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
################################################################################

resource "azurerm_subnet" "private" {
  depends_on = [
    azurerm_network_security_group.nacl
  ]
  for_each             = tomap(local.disaster_recovery)
  name                 = "${each.key}-vnet-subnet-private"
  resource_group_name  = each.key
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes = [
    cidrsubnet(each.value[0], 4, 0)
  ]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "public" {
  depends_on = [
    azurerm_subnet.private
  ]
  for_each             = tomap(local.disaster_recovery)
  name                 = "${each.key}-vnet-subnet-public"
  resource_group_name  = each.key
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes = [
    cidrsubnet(each.value[0], 4, 0)
  ]
  default_outbound_access_enabled = true
}

################################################################################
# Subnets Association
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association
################################################################################

resource "azurerm_subnet_network_security_group_association" "private" {
  depends_on = [
    azurerm_subnet.public
  ]
  for_each                  = tomap(local.disaster_recovery)
  subnet_id                 = azurerm_subnet.private[each.key].id
  network_security_group_id = azurerm_network_security_group.nacl[each.key].id
}

resource "azurerm_subnet_network_security_group_association" "public" {
  depends_on = [
    azurerm_subnet_network_security_group_association.private
  ]
  for_each                  = tomap(local.disaster_recovery)
  subnet_id                 = azurerm_subnet.public[each.key].id
  network_security_group_id = azurerm_network_security_group.nacl[each.key].id
}

################################################################################
# NAT - Public IP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
################################################################################

resource "azurerm_public_ip" "nat" {
  depends_on = [
    azurerm_subnet_network_security_group_association.public
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-nat"
  resource_group_name = each.key
  location            = each.key
  allocation_method   = "Static"
  sku                 = "StandardV2"

  tags = local.tags
}

################################################################################
# NAT
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway
################################################################################

resource "azurerm_nat_gateway" "nat" {
  depends_on = [
    azurerm_public_ip.nat
  ]
  for_each                = tomap(local.disaster_recovery)
  name                    = "${each.key}-nat-gateway"
  location                = each.key
  resource_group_name     = each.key
  sku_name                = "StandardV2"
  idle_timeout_in_minutes = 4
}

################################################################################
# NAT IP Association
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway_public_ip_association
################################################################################

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  depends_on = [
    azurerm_nat_gateway.nat
  ]
  for_each             = tomap(local.disaster_recovery)
  nat_gateway_id       = azurerm_nat_gateway.nat[each.key].id
  public_ip_address_id = azurerm_public_ip.nat[each.key].id
}

################################################################################
# NAT Subnet Association
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_nat_gateway_association
################################################################################

resource "azurerm_subnet_nat_gateway_association" "nat" {
  depends_on = [
    azurerm_nat_gateway_public_ip_association.nat
  ]
  for_each       = tomap(local.disaster_recovery)
  subnet_id      = azurerm_subnet.private[each.key].id
  nat_gateway_id = azurerm_nat_gateway.nat[each.key].id
}

################################################################################
# Route Table
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table
################################################################################

resource "azurerm_route_table" "public" {
  depends_on = [
    azurerm_subnet_nat_gateway_association.nat
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-route-public"
  location            = each.key
  resource_group_name = each.key

  route {
    name           = "${each.key}-route-public-vnet"
    address_prefix = azurerm_virtual_network.vnet[each.key].address_space[0]
    next_hop_type  = "VnetLocal"
  }

  route {
    name           = "${each.key}-route-public-online"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }

  tags = local.tags
}

################################################################################
# Route Table Assciation
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table
################################################################################

resource "azurerm_subnet_route_table_association" "public" {
  depends_on = [
    azurerm_subnet_nat_gateway_association.nat
  ]
  for_each       = tomap(local.disaster_recovery)
  subnet_id      = azurerm_subnet.public[each.key].id
  route_table_id = azurerm_route_table.public[each.key].id
}
