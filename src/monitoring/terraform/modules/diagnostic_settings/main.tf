# Generic: target_resource_id is a plain string in the azurerm provider, so
# unlike the Bicep equivalent (which needs a typed `existing` resource per
# target type), one module here covers every resource type. For storage
# account blob logs specifically, pass "${storage_account_id}/blobServices/default"
# as target_resource_id — blob read/write/delete logs are emitted at that
# sub-resource, not the storage account itself.

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = var.name
  target_resource_id         = var.target_resource_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = var.log_category_groups
    content {
      category_group = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = var.metric_categories
    content {
      category = metric.value
    }
  }
}
