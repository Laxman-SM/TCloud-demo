terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.33.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  backend "remote" {
    hostname = "app.terraform.io"
    organization = "vystmo-inc"

    workspaces {
      name = "gh-actions-demo"
    }
  }
}

provider "azurerm" {
  # skip provider rego because we are using a service principal with limited access to Azure
  skip_provider_registration = "true"
  features {}
}


/**

resource "azurerm_resource_group" "rg-tcloud-azure" {
  name     = "rg-tcloud-azure"
  location = "northcentralus"
}

resource "azurerm_virtual_network" "azcloud" {
  name                = "az-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg-tcloud-azure.location
  resource_group_name = azurerm_resource_group.rg-tcloud-azure.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg-tcloud-azure.name
  virtual_network_name = azurerm_virtual_network.azcloud.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints = ["Microsoft.Storage"]
}

**/

# module "keyvault" {
#  source  = "claranet/keyvault/azurerm"
#  version = "4.0.0"
#}

variable "environment" {
  default = "development"
  }

variable "location" {
  default = "northcentralus"
  }

resource "azurerm_resource_group" "rg" {
  name     = "tf-var.environment-rg"
  location = var.location
}

resource "azurerm_virtual_network" "aks" {
  name                = "aks-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks" {
  name                 =  "aks-subnet"
  resource_group_name  =  azurerm_resource_group.rg.name
  virtual_network_name =  azurerm_virtual_network.aks.name
  address_prefixes     = "10.1.0.0/24"
}


resource "azurerm_virtual_network" "backend" {
  name                = "backend-vnet"
  address_space       = ["10.2.0.0/16"]
  location            =  azurerm_resource_group.rg.location
  resource_group_name =  azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "backend" {
  name                 = "backend-subnet"
  resource_group_name  =  azurerm_resource_group.rg.name
  virtual_network_name =  azurerm_virtual_network.backend.name
  address_prefixes       = "10.2.0.0/24"
}

resource "azurerm_virtual_network_peering" "peering1" {
  name                      = "aks2backend"
  resource_group_name       =  azurerm_resource_group.rg.name
  virtual_network_name      =  azurerm_virtual_network.aks.name
  remote_virtual_network_id =  azurerm_virtual_network.backend.id
}

resource "azurerm_virtual_network_peering" "peering2" {
  name                      = "backend2aks"
  resource_group_name       =  azurerm_resource_group.rg.name
  virtual_network_name      =  azurerm_virtual_network.backend.name
  remote_virtual_network_id =  azurerm_virtual_network.aks.id
}
