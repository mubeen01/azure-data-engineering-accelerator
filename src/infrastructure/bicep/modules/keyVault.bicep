@description('Name of the Key Vault. Must be globally unique, 3-24 chars.')
param name string

@description('Azure region.')
param location string

@description('Entra tenant ID that owns this vault.')
param tenantId string = subscription().tenantId

@description('Enable purge protection. Recommended true for anything beyond a throwaway dev environment.')
param enablePurgeProtection bool = false

param tags object = {}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true // RBAC role assignments (modules/rbac.bicep), not legacy access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: enablePurgeProtection
  }
}

output id string = keyVault.id
output name string = keyVault.name
output uri string = keyVault.properties.vaultUri
