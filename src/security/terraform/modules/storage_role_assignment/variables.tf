variable "storage_account_id" {
  type        = string
  description = "Resource ID of the storage account to grant access to."
}

variable "principal_id" {
  type        = string
  description = "Principal ID to grant access to."
}

variable "role_definition_name" {
  type        = string
  description = "\"Storage Blob Data Reader\" for consumers; \"Storage Blob Data Contributor\" for anything that writes back (e.g. the Databricks Access Connector for Unity Catalog)."
  default     = "Storage Blob Data Reader"

  validation {
    condition     = contains(["Storage Blob Data Reader", "Storage Blob Data Contributor"], var.role_definition_name)
    error_message = "role_definition_name must be \"Storage Blob Data Reader\" or \"Storage Blob Data Contributor\"."
  }
}
