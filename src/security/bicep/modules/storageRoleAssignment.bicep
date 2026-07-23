@description('Name of an existing storage account.')
param storageAccountName string

@description('Principal ID to grant access to.')
param principalId string

@description('Principal type — ServicePrincipal covers both managed identities and app registrations.')
param principalType string = 'ServicePrincipal'

@allowed([
  'StorageBlobDataReader'
  'StorageBlobDataContributor'
])
@description('StorageBlobDataReader for consumers (e.g. the shared identity); StorageBlobDataContributor for anything that writes back (e.g. the Databricks Access Connector for Unity Catalog).')
param role string = 'StorageBlobDataReader'

var roleDefinitionIds = {
  StorageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  StorageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, role)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds[role])
    principalId: principalId
    principalType: principalType
  }
}
