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
# Data - Load Balancer
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/lb
################################################################################

# data "azurerm_lb" "kubernetes_backend_lb" {
#   for_each            = tomap(local.disaster_recovery)
#   name                = "${each.key}-kube-lb"
#   resource_group_name = each.key
# }

################################################################################
# Load Balancer
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb
################################################################################

resource "azurerm_lb" "kubernetes_backend_lb" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-kube-lb"
  location            = each.key
  resource_group_name = each.key
  sku = "Standard"
  sku_tier = "Regional"
}

################################################################################
# Subnets
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
################################################################################

resource "azurerm_subnet" "apim" {
  for_each             = tomap(local.disaster_recovery)
  name                 = "${each.key}-apim"
  resource_group_name  = each.key
  virtual_network_name = data.azurerm_virtual_network.vnet[each.key].name
  address_prefixes = [
    cidrsubnet(data.azurerm_virtual_network.vnet[each.key].address_space[0], 4, 5)
  ]
  default_outbound_access_enabled = true

  # Service endpoints help APIM seamlessly access platform infrastructure
  service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault"]
}

################################################################################
# API - Public IP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
################################################################################

resource "azurerm_public_ip" "apim" {
  depends_on = [
    azurerm_subnet.apim
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-ip-apim"
  resource_group_name = each.key
  location            = each.key
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "internal-apim-mgmt-gateway"
}

################################################################################
# VNET Network Security Group
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group
################################################################################

resource "azurerm_network_security_group" "apim" {
  depends_on = [
    azurerm_public_ip.apim
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-nsg-apim"
  resource_group_name = each.key
  location            = each.key

  security_rule {
    name                       = "Allow_APIM_Management"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow_Azure_Load_Balancer"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6390"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
  }
}

################################################################################
# Subnets Association
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association
################################################################################

resource "azurerm_subnet_network_security_group_association" "apim" {
  depends_on = [
    azurerm_network_security_group.apim
  ]
  for_each                  = tomap(local.disaster_recovery)
  subnet_id                 = azurerm_subnet.apim[each.key].id
  network_security_group_id = azurerm_network_security_group.apim[each.key].id
}

################################################################################
# API
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management
################################################################################

resource "azurerm_api_management" "apim" {
  depends_on = [
    azurerm_subnet_network_security_group_association.apim
  ]
  for_each             = tomap(local.disaster_recovery)
  name                 = "${each.key}-apim"
  resource_group_name  = each.key
  location             = each.key
  publisher_name       = "Stratosphere"
  publisher_email      = "admin@stratoshpere.com"
  sku_name             = "Premium_1"
  virtual_network_type = "Internal"
  public_network_access_enabled = true
  public_ip_address_id = azurerm_public_ip.apim[each.key].id

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim[each.key].id
  }
}

################################################################################
# API Backend
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_backend
################################################################################

# resource "azurerm_api_management_backend" "kubernetes_backend" {
#   depends_on = [
#     azurerm_api_management.apim
#   ]
#   for_each            = tomap(local.disaster_recovery)
#   name                = "${each.key}-kube-backend"
#   resource_group_name = each.key
#   api_management_name = azurerm_api_management.apim[each.key].name
#   protocol            = "http"
#   url                 = "http://${azurerm_lb.kubernetes_backend_lb[each.key].private_ip_address}"
#   # resource_id         = "https://azure.com${azurerm_lb.kubernetes_backend_lb[each.key].id}"
# }

################################################################################
# API Policy
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_policy
################################################################################

# resource "azurerm_api_management_api_policy" "kubernetes_backend" {
#   depends_on = [
#     azurerm_api_management_backend.kubernetes_backend
#   ]
#   for_each            = tomap(local.disaster_recovery)
#   api_name            = "${each.key}-kube-backend-policy"
#   api_management_name = azurerm_api_management.apim[each.key].name
#   resource_group_name = each.key

#   xml_content = <<XML
# <policies>
#   <inbound>
#     <base />
#     <choose>
#         <when condition="@(context.Request.Url == "pod")">
#           <set-backend-service backend-id="${azurerm_api_management_backend.kubernetes_backend[each.key].name}" />
#         </when>
#         <otherwise>
#           <!-- Policies to apply if none of the above match -->
#         </otherwise>
#     </choose>
#   </inbound>
# </policies>
# XML
# }
