variable "name" {
  type        = string
  description = "Name of the Databricks Access Connector."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into."
}

variable "tags" {
  type    = map(string)
  default = {}
}
