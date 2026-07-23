resource "azurerm_key_vault" "this" {
  name                       = var.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true # RBAC role assignments (modules/rbac), not legacy access policies
  purge_protection_enabled   = var.enable_purge_protection
  soft_delete_retention_days = 90
  tags                       = var.tags
}
