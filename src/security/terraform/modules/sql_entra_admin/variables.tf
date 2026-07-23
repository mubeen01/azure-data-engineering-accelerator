variable "sql_server_name" {
  type        = string
  description = "Name of an existing SQL logical server."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the SQL server lives in."
}

variable "entra_admin_login" {
  type        = string
  description = "Display name of the Entra ID user/group to set as SQL admin."
}

variable "entra_admin_object_id" {
  type        = string
  description = "Object ID of that Entra ID user/group."
}

variable "tenant_id" {
  type        = string
  description = "Entra tenant ID."
}
