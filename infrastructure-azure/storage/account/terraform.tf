terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.80.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.1.0"
    }
  }

  required_version = "~> 1.6"
}

provider "azurerm" {
  features {}
}

provider "azuread" {
}
