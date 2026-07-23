# ADF's Managed Identity storage auth (src/adf/linkedService/ls_AdeaDataLake_Storage.json)
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.principal_id
}

# ADF's Key Vault-referenced SQL password (src/adf/linkedService/ls_AdeaDW_AzureSqlDatabase.json)
resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.principal_id
}
