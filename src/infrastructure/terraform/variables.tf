variable "environment_name" {
  type        = string
  description = "Short environment name, e.g. dev/test/prod — used to build resource names."
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment_name)
    error_message = "environment_name must be one of dev, test, prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region for every resource."
  default     = "eastus2"
}

variable "sql_admin_login" {
  type        = string
  description = "SQL authentication admin login for the AdeaDW server."
  default     = "adeaadmin"
}

variable "sql_admin_password" {
  type        = string
  description = "SQL authentication admin password for the AdeaDW server. No default — must be supplied."
  sensitive   = true
}

variable "enable_key_vault_purge_protection" {
  type        = bool
  description = "Enable Key Vault purge protection. Recommended true outside of throwaway dev environments."
  default     = false
}
