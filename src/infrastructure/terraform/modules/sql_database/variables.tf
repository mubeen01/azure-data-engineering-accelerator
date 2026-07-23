variable "server_name" {
  type        = string
  description = "Logical SQL server name. Must be globally unique."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into."
}

variable "database_name" {
  type        = string
  description = "Database name — must match src/sql/01-database/01_Create_Database.sql."
  default     = "AdeaDW"
}

variable "admin_login" {
  type        = string
  description = "SQL authentication admin login."
}

variable "admin_password" {
  type        = string
  description = "SQL authentication admin password."
  sensitive   = true
}

variable "sku_name" {
  type        = string
  description = "Database SKU. Basic is a cheap default for a dev/accelerator environment — size up for anything real."
  default     = "Basic"
}

variable "allow_azure_services" {
  type        = bool
  description = "Allow Azure services (ADF, Databricks) to reach this server."
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
