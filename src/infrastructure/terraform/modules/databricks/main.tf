resource "azurerm_databricks_workspace" "this" {
  name                        = var.name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  sku                         = var.sku_name
  managed_resource_group_name = var.managed_resource_group_name
  tags                        = var.tags
}
