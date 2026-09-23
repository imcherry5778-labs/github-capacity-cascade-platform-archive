output "resource_group_name" {
  description = "Terraform state resource group name."
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Terraform state storage account name."
  value       = azurerm_storage_account.state.name
}

output "storage_account_id" {
  description = "Terraform state storage account resource ID."
  value       = azurerm_storage_account.state.id
}

output "container_name" {
  description = "Terraform state blob container name."
  value       = azurerm_storage_container.state.name
}
