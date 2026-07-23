resource "azurerm_data_factory" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  identity {
    type = "SystemAssigned" # src/adf/README.md's auth model relies on this for storage + Key Vault access
  }
}
