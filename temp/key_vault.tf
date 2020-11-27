data "azuread_group" "main" {
  count = length(local.group_names)
  name  = local.group_names[count.index]
}

data "azuread_user" "main" {
  count               = length(local.user_principal_names)
  user_principal_name = local.user_principal_names[count.index]
}

data "azurerm_client_config" "main" {}

resource "azurerm_key_vault" "main" {
  name                = var.name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.main.tenant_id

  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_template_deployment = var.enabled_for_template_deployment
  tags                            = var.tags

  sku_name = var.sku

  dynamic "access_policy" {
    for_each = local.combined_access_policies

    content {
      tenant_id = data.azurerm_client_config.main.tenant_id
      object_id = access_policy.value.object_id

      certificate_permissions = access_policy.value.certificate_permissions
      key_permissions         = access_policy.value.key_permissions
      secret_permissions      = access_policy.value.secret_permissions
      storage_permissions     = access_policy.value.storage_permissions
    }
  }

  dynamic "access_policy" {
    for_each = local.service_principal_object_id != "" ? [local.self_permissions] : []

    content {
      tenant_id = data.azurerm_client_config.main.tenant_id
      object_id = access_policy.value.object_id

      #certificate_permissions = access_policy.value.certificate_permissions
      key_permissions    = access_policy.value.key_permissions
      secret_permissions = access_policy.value.secret_permissions
      #storage_permissions     = access_policy.value.storage_permissions
    }
  }


}

resource "azurerm_key_vault_secret" "main" {
  for_each     = var.secrets
  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.main.id
}
