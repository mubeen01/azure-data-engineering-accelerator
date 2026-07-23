variable "name" {
  type        = string
  description = "Storage account name. Must be globally unique, lowercase alphanumeric, 3-24 chars."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into."
}

variable "container_names" {
  type        = list(string)
  description = "Blob containers to create, matching what src/adf and src/databricks expect."
  default     = ["raw", "checkpoints"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
