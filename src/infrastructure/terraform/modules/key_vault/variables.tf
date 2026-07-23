variable "name" {
  type        = string
  description = "Key Vault name. Must be globally unique, 3-24 chars."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy into."
}

variable "tenant_id" {
  type        = string
  description = "Entra tenant ID that owns this vault."
}

variable "enable_purge_protection" {
  type        = bool
  description = "Recommended true outside of throwaway dev environments."
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
