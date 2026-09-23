variable "location" {
  description = "Azure region for the Terraform state resource group and storage account."
  type        = string
  default     = "koreacentral"
}

variable "resource_group_name" {
  description = "Resource group dedicated to Terraform state bootstrap resources."
  type        = string
  default     = "rg-github-capacity-cascade-platform-tfstate"
}

variable "storage_account_name" {
  description = "Globally unique Azure Storage Account name for Terraform state. Use 3-24 lowercase letters or digits."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must contain only 3-24 lowercase letters or digits."
  }
}

variable "container_name" {
  description = "Private blob container used by foundation and environment Terraform backends."
  type        = string
  default     = "tfstate"

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])?$", var.container_name))
    error_message = "container_name must be a valid lowercase Azure blob container name with 3-63 characters."
  }
}

variable "tags" {
  description = "Tags applied to bootstrap resources."
  type        = map(string)
  default = {
    project    = "github-capacity-cascade-platform"
    managed-by = "terraform"
    lifecycle  = "bootstrap"
  }
}
