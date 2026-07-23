variable "name" {
  type        = string
  description = "Name of the diagnostic setting."
  default     = "send-to-log-analytics"
}

variable "target_resource_id" {
  type        = string
  description = "Resource ID to enable diagnostics on. For storage account blob logs, append /blobServices/default."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace resource ID to send logs/metrics to."
}

variable "log_category_groups" {
  type        = list(string)
  description = "Diagnostic log category groups to enable."
  default     = ["allLogs"]
}

variable "metric_categories" {
  type        = list(string)
  description = "Metric categories to enable. Empty list to skip metrics for resource types that don't support AllMetrics (e.g. Key Vault does)."
  default     = ["AllMetrics"]
}
