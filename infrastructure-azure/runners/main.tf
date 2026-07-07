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
# Data - Storage Account
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account
################################################################################

data "azurerm_storage_account" "stratosphere" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}stratos"
  resource_group_name = each.key
}

################################################################################
# Data - Storage Container
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account
################################################################################

data "azurerm_storage_container" "container" {
  for_each           = tomap(local.disaster_recovery)
  name               = "${each.key}-container-account"
  storage_account_id = data.azurerm_storage_account.stratosphere[each.key].id
}

################################################################################
# Data - Key Vault
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault
################################################################################

data "azurerm_key_vault" "stratosphere" {
  for_each            = tomap(local.disaster_recovery)
  name                = each.key
  resource_group_name = each.key
}

################################################################################
# Data - Key Vault Secret - GITHUB ORG
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret
################################################################################

data "azurerm_key_vault_secret" "github_org_url" {
  for_each     = tomap(local.disaster_recovery)
  name         = "GitHubOrgUrl"
  key_vault_id = data.azurerm_key_vault.stratosphere[each.key].id
}

data "azurerm_key_vault_secret" "github_org" {
  for_each     = tomap(local.disaster_recovery)
  name         = "GitHubOrg"
  key_vault_id = data.azurerm_key_vault.stratosphere[each.key].id
}

################################################################################
# Data - Key Vault Secret - GITHUB PAT
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret
################################################################################

data "azurerm_key_vault_secret" "github_pat" {
  for_each     = tomap(local.disaster_recovery)
  name         = "GitHubPat"
  key_vault_id = data.azurerm_key_vault.stratosphere[each.key].id
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
# RUNNER - Public IP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
################################################################################

resource "azurerm_public_ip" "runner" {
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-runner"
  resource_group_name = each.key
  location            = each.key
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.tags
}

################################################################################
# Network Interface
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
################################################################################

resource "azurerm_network_interface" "runner" {
  depends_on = [
    azurerm_public_ip.runner
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-nic"
  location            = each.key
  resource_group_name = each.key

  ip_configuration {
    name = "${each.key}-nic-config"
    # subnet_id                     = data.azurerm_subnet.public[each.key].id
    subnet_id                     = data.azurerm_subnet.private[each.key].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.runner[each.key].id
  }
}

################################################################################
# NIC Association
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_security_group_association
################################################################################

resource "azurerm_network_interface_security_group_association" "runner" {
  depends_on = [
    azurerm_network_interface.runner
  ]
  for_each                  = tomap(local.disaster_recovery)
  network_interface_id      = azurerm_network_interface.runner[each.key].id
  network_security_group_id = data.azurerm_network_security_group.nacl[each.key].id
}

################################################################################
# SSH
# https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key
################################################################################

resource "tls_private_key" "runner" {
  depends_on = [
    azurerm_network_interface_security_group_association.runner
  ]
  algorithm = "RSA"
  rsa_bits  = 4096
}

################################################################################
# VM
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
################################################################################

resource "azurerm_linux_virtual_machine" "runner" {
  depends_on = [
    tls_private_key.runner
  ]
  for_each            = tomap(local.disaster_recovery)
  name                = "${each.key}-runner"
  location            = each.key
  resource_group_name = each.key
  size                = "Standard_D2s_v3"

  network_interface_ids = [
    azurerm_network_interface.runner[each.key].id
  ]

  os_disk {
    name                 = "runner-data"
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

  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.stratosphere[each.key].id
    ]
  }

  # computer_name  = "hostname"
  computer_name  = azurerm_public_ip.runner[each.key].ip_address
  admin_username = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.runner.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = data.azurerm_storage_account.stratosphere[each.key].primary_blob_endpoint
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/bootstrap.sh", {
    CLIENT_ID      = "${data.azurerm_user_assigned_identity.stratosphere[each.key].client_id}"
    VAULT          = "${data.azurerm_key_vault.stratosphere[each.key].name}"
    GITHUB_PAT     = "${data.azurerm_key_vault_secret.github_pat[each.key].value}"
    GITHUB_ORG_URL = "${data.azurerm_key_vault_secret.github_org_url[each.key].value}"
    GITHUB_ORG     = "${data.azurerm_key_vault_secret.github_org[each.key].value}"
  }))
}
