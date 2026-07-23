@description('Name of an existing Key Vault in this resource group.')
param keyVaultName string

@description('Secret name — must match the secretName referenced in src/adf/linkedService/ls_AdeaDW_AzureSqlDatabase.json.')
param secretName string

@secure()
@description('Secret value.')
param secretValue string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: secretName
  properties: {
    value: secretValue
  }
}
