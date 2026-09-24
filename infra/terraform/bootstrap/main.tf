locals {
  github_actions_oidc_issuer   = "https://token.actions.githubusercontent.com"
  github_actions_oidc_audience = "api://AzureADTokenExchange"
  github_actions_oidc_subject  = "repo:imcherry5778-labs@273613742/github-capacity-cascade-platform@1377253823:environment:azure"
}

resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "foundation" {
  name     = var.foundation_resource_group_name
  location = var.location

  tags = merge(var.tags, {
    lifecycle = "foundation"
  })
}

resource "azurerm_resource_group" "environment" {
  name     = var.environment_resource_group_name
  location = var.location

  tags = merge(var.tags, {
    lifecycle = "environment"
  })
}

resource "azurerm_storage_account" "state" {
  name                = var.storage_account_name
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  public_network_access_enabled   = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "state" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_user_assigned_identity" "github_actions" {
  name                = var.github_actions_identity_name
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "github_actions_azure" {
  name                      = "github-actions-azure"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_actions.id

  issuer   = local.github_actions_oidc_issuer
  subject  = local.github_actions_oidc_subject
  audience = [local.github_actions_oidc_audience]
}

resource "azurerm_role_assignment" "github_actions_state_blob" {
  scope                = azurerm_storage_container.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_actions_foundation_contributor" {
  scope                = azurerm_resource_group.foundation.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_actions_foundation_rbac_admin" {
  scope                = azurerm_resource_group.foundation.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_actions_environment_contributor" {
  scope                = azurerm_resource_group.environment.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_actions_environment_rbac_admin" {
  scope                = azurerm_resource_group.environment.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type       = "ServicePrincipal"
}
