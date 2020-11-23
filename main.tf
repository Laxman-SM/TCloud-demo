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


resource "azurerm_resource_group" "rg-tcloud-azure" {
  name     = "rg-tcloud-azure"
  location = "northcentralus"
}

resource "azurerm_virtual_network" "tfcloud" {
  name                = "tf-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg-tcloud-azure.location
  resource_group_name = azurerm_resource_group.rg-tcloud-azure.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg-tcloud-azure.name
  virtual_network_name = azurerm_virtual_network.tfcloud.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_storage_account" "tfstorage" {
  name                     = "tfendpint"
  location                 = azurerm_resource_group.rg-tcloud-azure.location
  resource_group_name      = azurerm_resource_group.rg-tcloud-azure.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version      = "TLS1_2"
  queue_properties  {
  logging {
        delete                = true
        read                  = true
        write                 = true
        version               = "1.0"
        retention_policy_days = 10
    }
  }
  tags = {
    environment = "staging"
  }
    network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.internal.id]
  }
}
