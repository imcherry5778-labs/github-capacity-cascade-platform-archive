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

output "foundation_resource_group_name" {
  description = "Resource Group name consumed by the foundation Terraform stack."
  value       = azurerm_resource_group.foundation.name
}

output "foundation_resource_group_id" {
  description = "Resource Group ID consumed by the foundation Terraform stack."
  value       = azurerm_resource_group.foundation.id
}

output "environment_resource_group_name" {
  description = "Resource Group name consumed by the environment Terraform stack."
  value       = azurerm_resource_group.environment.name
}

output "environment_resource_group_id" {
  description = "Resource Group ID consumed by the environment Terraform stack."
  value       = azurerm_resource_group.environment.id
}

output "github_actions_identity_id" {
  description = "Resource ID of the GitHub Actions user-assigned managed identity."
  value       = azurerm_user_assigned_identity.github_actions.id
}

output "github_actions_identity_client_id" {
  description = "Client ID used by GitHub Actions Azure login."
  value       = azurerm_user_assigned_identity.github_actions.client_id
}

output "github_actions_identity_principal_id" {
  description = "Principal ID used for scoped Azure RBAC assignments."
  value       = azurerm_user_assigned_identity.github_actions.principal_id
}

output "github_actions_identity_tenant_id" {
  description = "Microsoft Entra tenant ID for the GitHub Actions managed identity."
  value       = azurerm_user_assigned_identity.github_actions.tenant_id
}

output "github_actions_oidc_subject" {
  description = "Immutable GitHub Actions OIDC subject trusted by the Azure federated credential."
  value       = local.github_actions_oidc_subject
}
