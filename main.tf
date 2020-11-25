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
  default = [
    "northcentralus",
    "southeastasia",
  ]
  }

variable "vnet_address_space" {
  default = [
    "10.0.0.0/16",
    "10.1.0.0/16",
  ]
}

resource "azurerm_resource_group" "vnet" {
  name     = "rg-global-vnet-peering-${count.index}"
  location = element(var.location, count.index)
  count    = length(var.location)
}

resource "azurerm_virtual_network" "vnet" {
  count               = length(var.location)
  name                = "vnet-${count.index}"
  address_space       = [element(var.vnet_address_space, count.index)]
  location            = element(azurerm_reource_group.vnet.*.location, count.index)
  resource_group_name = element(azurerm_resource_group.vnet.*.name, count.index)
}

resource "azurerm_subnet" "nva" {
  count                = length(var.location)
  name                 = "nva"
  resource_group_name  = element(azurerm_resource_group.vnet.*.name, count.index)
  virtual_network_name = element(azurerm_virtual_network.vnet.*.name, count.index)
  address_prefix = cidrsubnet(
    element(
      azurerm_virtual_network.vnet[count.index].address_space,
      count.index,
    ),
    13,
    0,
  ) # /29
}

# enable global peering between the two virtual network
resource "azurerm_virtual_network_peering" "peering" {
  count                        = length(var.location)
  name                         = "peering-to-${element(azurerm_virtual_network.vnet.*.name, 1 - count.index)}"
  resource_group_name          = element(azurerm_resource_group.vnet.*.name, count.index)
  virtual_network_name         = element(azurerm_virtual_network.vnet.*.name, count.index)
  remote_virtual_network_id    = element(azurerm_virtual_network.vnet.*.id, 1 - count.index)
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = false
}

/**
resource "azurerm_subnet" "aks" {
  name                 =  "aks-subnet"
  resource_group_name  =  azurerm_resource_group.vnet.name
  virtual_network_name =  azurerm_virtual_network.aks.name
  address_prefixes     = "10.1.0.0/24"
}


resource "azurerm_virtual_network" "backend" {
  name                = "backend-vnet"
  address_space       = ["10.2.0.0/16"]
  location            =  azurerm_resource_group.vnet.location
  resource_group_name =  azurerm_resource_group.vnet.name
}

resource "azurerm_subnet" "backend" {
  name                 = "backend-subnet"
  resource_group_name  =  azurerm_resource_group.vnet.name
  virtual_network_name =  azurerm_virtual_network.backend.name
  address_prefixes       = "10.2.0.0/24"
}

resource "azurerm_virtual_network_peering" "peering1" {
  name                      = "aks2backend"
  resource_group_name       =  azurerm_resource_group.vnet.name
  virtual_network_name      =  azurerm_virtual_network.aks.name
  remote_virtual_network_id =  azurerm_virtual_network.backend.id
}

resource "azurerm_virtual_network_peering" "peering2" {
  name                      = "backend2aks"
  resource_group_name       =  azurerm_resource_group.vnet.name
  virtual_network_name      =  azurerm_virtual_network.backend.name
  remote_virtual_network_id =  azurerm_virtual_network.aks.id
}

**/
#
