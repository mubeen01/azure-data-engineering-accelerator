# A shared identity for scenarios that aren't "one resource's own system-
# assigned identity" and aren't Unity Catalog specifically (that's
# databricks_access_connector) — e.g. a CI/CD pipeline authenticating via
# federated credentials instead of a stored secret. Granted storage read
# access via storage_role_assignment as a representative example; grant it
# further roles as each new need materializes.
resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
