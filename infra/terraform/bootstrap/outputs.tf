output "resource_group_name" {
  description = "Terraform bootstrap resource group name."
  value       = azurerm_resource_group.bootstrap.name
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

output "deployment_identity_client_id" {
  description = "Client ID used by azure/login for GitHub Actions OIDC authentication."
  value       = azurerm_user_assigned_identity.github_deploy.client_id
}

output "deployment_identity_principal_id" {
  description = "Principal ID used for Azure RBAC assignments."
  value       = azurerm_user_assigned_identity.github_deploy.principal_id
}

output "deployment_identity_tenant_id" {
  description = "Tenant ID for the deployment identity."
  value       = azurerm_user_assigned_identity.github_deploy.tenant_id
}

output "github_oidc_subject" {
  description = "GitHub OIDC subject trusted by the deployment identity."
  value       = azurerm_federated_identity_credential.github_azure_demo.subject
}
