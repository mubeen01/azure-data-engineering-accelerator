# The Azure-native identity Unity Catalog storage credentials authenticate
# with — not a generic user-assigned identity. Grant this connector's
# identity Storage Blob Data Contributor (storage_role_assignment module),
# then reference its ID from a databricks_storage_credential resource (the
# databricks provider — no azurerm equivalent exists for that Unity
# Catalog-side object; see src/security/README.md).
resource "azurerm_databricks_access_connector" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}
