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
# Data - VNET Network Security Group
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/network_security_group
################################################################################

data "azurerm_network_security_group" "nacl" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-sg-nacl"
  resource_group_name = each.key
}

################################################################################
# Data - Subnets
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet
################################################################################

data "azurerm_subnet" "private" {
  for_each             = tomap(local.disaster_recovery)
  name                 = "${each.key}-vnet-subnet-private"
  virtual_network_name = data.azurerm_virtual_network.vnet[each.key].name
  resource_group_name  = each.key
}

data "azurerm_subnet" "public" {
  for_each             = tomap(local.disaster_recovery)
  name                 = "${each.key}-vnet-subnet-public"
  virtual_network_name = data.azurerm_virtual_network.vnet[each.key].name
  resource_group_name  = each.key
}

################################################################################
# SSH
# https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key
################################################################################

resource "tls_private_key" "aks" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

################################################################################
# AKS
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster
################################################################################

resource "azurerm_kubernetes_cluster" "aks" {
  depends_on = [
    tls_private_key.aks
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-aks"
  location            = each.key
  resource_group_name = each.key
  dns_prefix          = "${each.key}-aks"
  kubernetes_version  = "1.34"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                         = "${each.key}-aks-node-pool"
    vm_size                      = "Standard_D2_v2"
    node_count                   = 1
    os_disk_size_gb              = 30
    only_critical_addons_enabled = false
    vnet_subnet_id               = data.azurerm_subnet.private[each.key].id
    zones                        = ["1", "2", "3"]
    temporary_name_for_rotation  = "${each.key}-aks-node-pool-standby"
  }
  linux_profile {
    admin_username = "${each.key}-aks"

    ssh_key {
      key_data = tls_private_key.aks.public_key_openssh
    }
  }
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
}

################################################################################
# AKS - Extension
# https://registry.terraform.io/providers/hashicorp/Azurerm/latest/docs/resources/kubernetes_cluster_extension
################################################################################

resource "azurerm_kubernetes_cluster_extension" "container" {
  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]
  for_each       = tomap(local.disaster_recovery)
  name           = "${each.key}-containers-storage"
  cluster_id     = azurerm_kubernetes_cluster.aks[each.key].id
  extension_type = "microsoft.azurecontainerstoragev2"
}
