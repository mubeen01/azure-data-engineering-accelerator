resource "azurerm_monitor_action_group" "this" {
  name                = "ag-adea-ops"
  resource_group_name = var.resource_group_name
  short_name          = "adeaOps"
  tags                = var.tags

  email_receiver {
    name                    = "primary-email"
    email_address           = var.notification_email
    use_common_alert_schema = true
  }
}

# Fires on any failed ADF pipeline run — every load procedure already logs
# to audit.log_etl_run (src/sql), but this is the "someone should look at
# this now" layer on top, independent of anyone querying that table.
resource "azurerm_monitor_metric_alert" "adf_pipeline_failures" {
  name                = "alert-adf-pipeline-failures"
  resource_group_name = var.resource_group_name
  scopes              = [var.data_factory_id]
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.DataFactory/factories"
    metric_name      = "PipelineFailedRuns"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

# DTU-based tiers (Basic/S0 default in src/infrastructure) expose
# dtu_consumption_percent rather than cpu_percent.
resource "azurerm_monitor_metric_alert" "sql_high_dtu" {
  name                = "alert-sql-high-dtu"
  resource_group_name = var.resource_group_name
  scopes              = [var.sql_database_id]
  severity            = 3
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "dtu_consumption_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}
