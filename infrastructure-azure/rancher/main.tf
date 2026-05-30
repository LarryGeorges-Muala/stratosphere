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
# VM - Public IP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
################################################################################

resource "azurerm_public_ip" "vm" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-vm"
  resource_group_name = each.key
  location            = each.key
  allocation_method   = "Static"
  sku                 = "StandardV2"

  tags = local.tags
}

################################################################################
# Network Interface
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
################################################################################

resource "azurerm_network_interface" "vm" {
  depends_on = [
    azurerm_public_ip.vm
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-nic"
  location            = each.key
  resource_group_name = each.key

  ip_configuration {
    name                          = "${each.key}-nic-config"
    subnet_id                     = data.azurerm_subnet.public[each.key].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm[each.key].id
  }
}

################################################################################
# NIC Association
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_security_group_association
################################################################################

resource "azurerm_network_interface_security_group_association" "vm" {
  depends_on = [
    azurerm_network_interface.vm
  ]
  for_each                  = tomap(local.disaster_recovery)
  network_interface_id      = azurerm_network_interface.vm[each.key].id
  network_security_group_id = data.azurerm_network_security_group.nacl[each.key].id
}

################################################################################
# Storage
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
################################################################################

resource "azurerm_storage_account" "vm" {
  depends_on = [
    azurerm_network_interface_security_group_association.vm
  ]
  for_each                 = tomap(local.disaster_recovery)
  name                     = "${each.key}-vm-storage"
  location                 = each.key
  resource_group_name      = each.key
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

################################################################################
# SSH
# https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key
################################################################################

resource "tls_private_key" "vm" {
  depends_on = [
    azurerm_storage_account.vm
  ]
  algorithm = "RSA"
  rsa_bits  = 4096
}

################################################################################
# VM
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
################################################################################

resource "azurerm_linux_virtual_machine" "rancher" {
  depends_on = [
    tls_private_key.vm
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-rancher"
  location            = each.key
  resource_group_name = each.key
  size                = "Standard_DS2_v2"
  network_interface_ids = [
    azurerm_network_interface.vm[each.key].id
  ]

  os_disk {
    name                 = "rancher-data"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  computer_name  = "hostname"
  admin_username = "${each.key}-rancher"

  admin_ssh_key {
    username   = "${each.key}-rancher"
    public_key = tls_private_key.vm.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.vm[each.key].primary_blob_endpoint
  }

  custom_data = base64encode(file("${path.module}/scripts/bootstrap-rancher.sh"))
}
