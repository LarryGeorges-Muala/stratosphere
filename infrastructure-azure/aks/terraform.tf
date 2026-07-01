terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.79.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
    }
  }

  required_version = "~> 1.6"
}

provider "azurerm" {
  features {}
}
