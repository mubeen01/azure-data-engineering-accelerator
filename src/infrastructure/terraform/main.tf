# Provisions the containers referenced by src/adf/ and src/databricks/
# (storage, Key Vault, SQL, Data Factory, Databricks, Log Analytics) — it
# does not configure the detailed security/monitoring policy on top of them
# (RBAC beyond what ADF's identity needs, alert rules, Entra app
# registrations); that's Phase 7.

locals {
  tags = {
    project     = "azure-data-engineering-accelerator"
    environment = var.environment_name
  }

  # Keeps globally-unique resource names (storage, Key Vault, SQL server)
  # short and deterministic per tenant+environment, so re-applying this
  # config doesn't generate new names each time.
  unique_suffix = substr(md5("${data.azurerm_client_config.current.tenant_id}-${var.environment_name}"), 0, 8)
}

resource "azurerm_resource_group" "this" {
  name     = "rg-adea-${var.environment_name}"
  location = var.location
  tags     = local.tags
}

module "log_analytics" {
  source              = "./modules/log_analytics"
  name                = "log-adea-${var.environment_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

module "storage" {
  source              = "./modules/storage"
  name                = "stadea${local.unique_suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

module "key_vault" {
  source                  = "./modules/key_vault"
  name                    = "kv-adea-${local.unique_suffix}"
  location                = var.location
  resource_group_name     = azurerm_resource_group.this.name
  tenant_id               = data.azurerm_client_config.current.tenant_id
  enable_purge_protection = var.enable_key_vault_purge_protection
  tags                    = local.tags
}

module "sql_database" {
  source              = "./modules/sql_database"
  server_name         = "sql-adea-${local.unique_suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  admin_login         = var.sql_admin_login
  admin_password      = var.sql_admin_password
  tags                = local.tags
}

module "data_factory" {
  source              = "./modules/data_factory"
  name                = "adf-adea-${var.environment_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

module "databricks" {
  source                      = "./modules/databricks"
  name                        = "dbw-adea-${var.environment_name}"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.this.name
  managed_resource_group_name = "rg-adea-${var.environment_name}-databricks"
  tags                        = local.tags
}

# ADF's system-assigned identity needs Storage Blob Data Contributor +
# Key Vault Secrets User — see src/adf/README.md's auth model.
module "rbac" {
  source             = "./modules/rbac"
  storage_account_id = module.storage.id
  key_vault_id       = module.key_vault.id
  principal_id       = module.data_factory.principal_id
}

# Stores the SQL admin password as the secret ls_AdeaDW_AzureSqlDatabase.json
# references. Requires the identity running `terraform apply` to already
# hold "Key Vault Secrets Officer" (or higher) on the vault — enable_rbac_authorization
# means even the deployer isn't implicitly allowed to write secrets.
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "adea-dw-sql-password"
  value        = var.sql_admin_password
  key_vault_id = module.key_vault.id

  depends_on = [module.rbac]
}
