variable "storage_account_id" {
  type        = string
  description = "Resource ID of the storage account to grant access to."
}

variable "key_vault_id" {
  type        = string
  description = "Resource ID of the Key Vault to grant access to."
}

variable "principal_id" {
  type        = string
  description = "Principal ID to grant access to — the Data Factory system-assigned managed identity."
}
