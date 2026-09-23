resource "azurerm_resource_group" "foundation" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_dns_zone" "platform" {
  name                = var.dns_zone_name
  resource_group_name = azurerm_resource_group.foundation.name
  tags                = var.tags
}

resource "azurerm_key_vault" "platform" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name                   = "standard"
  rbac_authorization_enabled = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  public_network_access_enabled = true

  tags = var.tags
}
