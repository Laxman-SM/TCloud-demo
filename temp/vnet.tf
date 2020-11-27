locals {
  subnets = [
    for s in var.subnets : merge({
      name                      = ""
      address_prefix            = ""
      network_security_group_id = ""
      #route_table_id            = ""
      delegations       = []
      service_endpoints = []
    }, s)
  ]

  subnets_delegations = [
    for s in local.subnets : {
      name                      = s.name
      address_prefix            = s.address_prefix
      network_security_group_id = s.network_security_group_id
      # route_table_id            = s.route_table_id
      service_endpoints = s.service_endpoints
      delegations = [
        for d in s.delegations : {
          name = lower(split("/", d)[1])
          service_delegation = {
            name    = d
            actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
          }
        }
      ]
    }
  ]

  subnet_ids = { for s in azurerm_subnet.main : s.name => s.id }

  network_security_group_ids = {
    for s in local.subnets : s.name =>
    s.network_security_group_id if s.network_security_group_id != ""
  }



  network_security_group_associations = [
    for subnet, id in local.network_security_group_ids : {
      subnet_id                 = local.subnet_ids[subnet]
      network_security_group_id = id
    }
  ]


}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "main" {
  name                = var.name
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = var.address_space
  location            = coalesce(var.location, data.azurerm_resource_group.main.location)
  dns_servers         = var.dns_servers
}

resource "azurerm_subnet" "main" {
  count                = length(local.subnets_delegations)
  name                 = local.subnets_delegations[count.index].name
  resource_group_name  = azurerm_virtual_network.main.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name

  address_prefix = local.subnets_delegations[count.index].address_prefix

  dynamic "delegation" {
    for_each = local.subnets_delegations[count.index].delegations

    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }

  service_endpoints = local.subnets_delegations[count.index].service_endpoints

  lifecycle {
    #ignore_changes = ["network_security_group_id"]
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  count                     = length(local.network_security_group_associations)
  subnet_id                 = local.network_security_group_associations[count.index].subnet_id
  network_security_group_id = local.network_security_group_associations[count.index].network_security_group_id
}
