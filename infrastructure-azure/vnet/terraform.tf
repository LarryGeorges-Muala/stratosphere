terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
    }
  }

  backend "azurerm" {
    resource_group_name  = "southeastasia"
    storage_account_name = "southeastasiastratos"
    container_name       = "terraform"
    key                  = "terraform.tfstate" # The path/name of your state file inside the container
  }

  required_version = "~> 1.6"
}

provider "azurerm" {
  features {}
}
