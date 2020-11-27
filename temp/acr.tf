resource "azurerm_container_registry" "acr" {
  name                = var.acr.name
  resource_group_name = var.resource_group
  location            = var.location
  sku                 = var.acr.sku
  admin_enabled       = var.acr.admin_enabled

  tags = var.tags
}