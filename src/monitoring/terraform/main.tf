# Deploy this AFTER src/infrastructure/terraform (a separate state) — it
# wires diagnostic settings + alerts onto resources that already exist via
# data sources, it doesn't create them.

data "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
}

data "azurerm_storage_account" "this" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault" "this" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

data "azurerm_mssql_server" "this" {
  name                = var.sql_server_name
  resource_group_name = var.resource_group_name
}

data "azurerm_mssql_database" "this" {
  name      = var.sql_database_name
  server_id = data.azurerm_mssql_server.this.id
}

data "azurerm_data_factory" "this" {
  name                = var.data_factory_name
  resource_group_name = var.resource_group_name
}

data "azurerm_databricks_workspace" "this" {
  name                = var.databricks_workspace_name
  resource_group_name = var.resource_group_name
}

# Blob read/write/delete logs are emitted at the blob service sub-resource,
# not the storage account itself — a common gotcha with storage diagnostics.
module "storage_diagnostics" {
  source                     = "./modules/diagnostic_settings"
  target_resource_id         = "${data.azurerm_storage_account.this.id}/blobServices/default"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this.id
  metric_categories          = ["Transaction"]
}

module "key_vault_diagnostics" {
  source                     = "./modules/diagnostic_settings"
  target_resource_id         = data.azurerm_key_vault.this.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this.id
}

module "sql_database_diagnostics" {
  source                     = "./modules/diagnostic_settings"
  target_resource_id         = data.azurerm_mssql_database.this.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this.id
  metric_categories          = ["Basic"]
}

module "data_factory_diagnostics" {
  source                     = "./modules/diagnostic_settings"
  target_resource_id         = data.azurerm_data_factory.this.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this.id
}

module "databricks_diagnostics" {
  source                     = "./modules/diagnostic_settings"
  target_resource_id         = data.azurerm_databricks_workspace.this.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this.id
  metric_categories          = []
}

module "alerts" {
  source              = "./modules/alerts"
  resource_group_name = var.resource_group_name
  notification_email  = var.notification_email
  data_factory_id     = data.azurerm_data_factory.this.id
  sql_database_id     = data.azurerm_mssql_database.this.id
  tags                = var.tags
}
