variable "name" {
  type        = string
  description = "Name of the Databricks workspace."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into."
}

variable "managed_resource_group_name" {
  type        = string
  description = "Name for the separate resource group Databricks manages internally (must not already exist)."
}

variable "sku_name" {
  type        = string
  description = "premium unlocks RBAC/cluster policies/Unity Catalog-related features used by src/databricks/."
  default     = "premium"

  validation {
    condition     = contains(["trial", "standard", "premium"], var.sku_name)
    error_message = "sku_name must be one of trial, standard, premium."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
