output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "storage_account_name" {
  value = module.storage.name
}

output "storage_dfs_endpoint" {
  value = module.storage.primary_dfs_endpoint
}

output "key_vault_name" {
  value = module.key_vault.name
}

output "key_vault_uri" {
  value = module.key_vault.uri
}

output "sql_server_fqdn" {
  value = module.sql_database.fqdn
}

output "sql_database_name" {
  value = module.sql_database.database_name
}

output "data_factory_name" {
  value = module.data_factory.name
}

output "databricks_workspace_url" {
  value = module.databricks.workspace_url
}

output "log_analytics_workspace_name" {
  value = module.log_analytics.name
}
