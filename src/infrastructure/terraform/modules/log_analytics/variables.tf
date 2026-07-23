variable "name" {
  type        = string
  description = "Name of the Log Analytics workspace."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into."
}

variable "retention_in_days" {
  type        = number
  description = "Retention period in days."
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
