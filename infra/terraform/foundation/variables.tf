variable "location" {
  description = "Azure region for regional foundation resources."
  type        = string
  default     = "koreacentral"
}

variable "resource_group_name" {
  description = "Resource group for long-lived project foundation resources."
  type        = string
  default     = "rg-github-capacity-cascade-platform-foundation"
}

variable "dns_zone_name" {
  description = "Project-dedicated public DNS zone delegated from the user's parent domain, for example platform.example.com."
  type        = string

  validation {
    condition     = length(trimspace(var.dns_zone_name)) > 0 && can(regex("^[A-Za-z0-9.-]+$", var.dns_zone_name))
    error_message = "dns_zone_name must be a non-empty DNS zone name."
  }
}

variable "key_vault_name" {
  description = "Globally unique Azure Key Vault name for persistent platform secrets."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]{1,22}[A-Za-z0-9])$", var.key_vault_name))
    error_message = "key_vault_name must use 3-24 letters, digits, or hyphens and start/end with a letter or digit."
  }
}

variable "tags" {
  description = "Tags applied to foundation resources."
  type        = map(string)
  default = {
    project    = "github-capacity-cascade-platform"
    managed-by = "terraform"
    lifecycle  = "foundation"
  }
}
