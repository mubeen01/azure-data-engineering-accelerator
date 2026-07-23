variable "resource_group_name" {
  type        = string
  description = "Resource group the src/infrastructure deployment created — deploy this into the same one."
}

variable "location" {
  type        = string
  description = "Azure region for the new shared managed identity."
}

variable "sql_server_name" {
  type        = string
  description = "SQL server name from the src/infrastructure deployment."
}

variable "entra_admin_login" {
  type        = string
  description = "Display name of the Entra ID user/group to set as SQL admin (ideally a group, e.g. \"adea-dba\")."
}

variable "entra_admin_object_id" {
  type        = string
  description = "Object ID of that Entra ID user/group."
}

variable "storage_account_name" {
  type        = string
  description = "Storage account name from the src/infrastructure deployment."
}

variable "environment_name" {
  type        = string
  description = "Short environment name — used to name the shared managed identity."
  default     = "dev"
}

variable "databricks_workspace_name" {
  type        = string
  description = "Databricks workspace name from the src/infrastructure deployment (used only to name the Access Connector consistently)."
  default     = ""
}

variable "enable_cicd_app" {
  type        = bool
  description = "Create the Entra ID app registration for external CI/CD. Off by default — app registration needs an Entra role beyond typical subscription Contributor (e.g. Application Administrator), so it's opt-in rather than assumed."
  default     = false
}

variable "github_federated_subject" {
  type        = string
  description = "GitHub OIDC subject claim to trust, e.g. repo:my-org/my-repo:ref:refs/heads/main. Required if enable_cicd_app is true."
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
