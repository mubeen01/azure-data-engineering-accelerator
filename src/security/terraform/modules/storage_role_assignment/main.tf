resource "azurerm_role_assignment" "this" {
  scope                = var.storage_account_id
  role_definition_name = var.role_definition_name
  principal_id         = var.principal_id
}
