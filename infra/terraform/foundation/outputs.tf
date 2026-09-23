output "resource_group_name" {
  description = "Foundation resource group name."
  value       = azurerm_resource_group.foundation.name
}

output "dns_zone_id" {
  description = "Azure DNS zone resource ID."
  value       = azurerm_dns_zone.platform.id
}

output "dns_zone_name" {
  description = "Delegated project DNS zone name."
  value       = azurerm_dns_zone.platform.name
}

output "dns_name_servers" {
  description = "Azure DNS name servers that must be delegated from the parent domain."
  value       = azurerm_dns_zone.platform.name_servers
}

output "key_vault_id" {
  description = "Persistent platform Key Vault resource ID."
  value       = azurerm_key_vault.platform.id
}

output "key_vault_uri" {
  description = "Persistent platform Key Vault URI."
  value       = azurerm_key_vault.platform.vault_uri
}
