resource "azurerm_storage_account" "this" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  is_hns_enabled                  = true # ADLS Gen2 — required by Auto Loader / AzureBlobFS linked service
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

resource "azurerm_storage_container" "this" {
  for_each              = toset(var.container_names)
  name                  = each.value
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}
