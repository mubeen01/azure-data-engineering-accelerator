# Deploy this AFTER src/infrastructure/terraform (a separate state) — it
# adds the security layer on top of what that deployment already created,
# via data sources; it doesn't duplicate the RBAC that src/infrastructure
# already grants ADF.

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_storage_account" "this" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

module "sql_entra_admin" {
  source                = "./modules/sql_entra_admin"
  sql_server_name       = var.sql_server_name
  resource_group_name   = var.resource_group_name
  entra_admin_login     = var.entra_admin_login
  entra_admin_object_id = var.entra_admin_object_id
  tenant_id             = data.azurerm_client_config.current.tenant_id
}

module "shared_identity" {
  source              = "./modules/user_assigned_identity"
  name                = "id-adea-shared-${var.environment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

module "shared_identity_storage_access" {
  source               = "./modules/storage_role_assignment"
  storage_account_id   = data.azurerm_storage_account.this.id
  principal_id         = module.shared_identity.principal_id
  role_definition_name = "Storage Blob Data Reader"
}

# Unity Catalog's Azure-native auth path: grant the connector's identity
# write access, then reference module.databricks_access_connector.id from a
# databricks_storage_credential resource (the databricks provider — see
# src/security/README.md for why that's not built here).
module "databricks_access_connector" {
  source              = "./modules/databricks_access_connector"
  name                = "dbac-adea-${var.environment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

module "databricks_access_connector_storage_access" {
  source               = "./modules/storage_role_assignment"
  storage_account_id   = data.azurerm_storage_account.this.id
  principal_id         = module.databricks_access_connector.principal_id
  role_definition_name = "Storage Blob Data Contributor"
}

# Opt-in: see enable_cicd_app's description for why this isn't created by default.
module "entra_cicd_app" {
  count                    = var.enable_cicd_app ? 1 : 0
  source                   = "./modules/entra_cicd_app"
  github_federated_subject = var.github_federated_subject
  resource_group_id        = data.azurerm_resource_group.this.id
}
