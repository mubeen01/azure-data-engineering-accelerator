variable "resource_group_name" {
  type        = string
  description = "Resource group the src/infrastructure deployment created — deploy this into the same one."
}

variable "log_analytics_workspace_name" {
  type        = string
  description = "Log Analytics workspace name from the src/infrastructure deployment."
}

variable "storage_account_name" {
  type        = string
  description = "Storage account name from the src/infrastructure deployment."
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault name from the src/infrastructure deployment."
}

variable "sql_server_name" {
  type        = string
  description = "SQL server name from the src/infrastructure deployment."
}

variable "sql_database_name" {
  type        = string
  description = "SQL database name from the src/infrastructure deployment."
  default     = "AdeaDW"
}

variable "data_factory_name" {
  type        = string
  description = "Data Factory name from the src/infrastructure deployment."
}

variable "databricks_workspace_name" {
  type        = string
  description = "Databricks workspace name from the src/infrastructure deployment."
}

variable "notification_email" {
  type        = string
  description = "Email address for alert notifications."
}

variable "tags" {
  type    = map(string)
  default = {}
}
