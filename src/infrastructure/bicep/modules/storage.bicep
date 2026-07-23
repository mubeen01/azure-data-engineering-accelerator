@description('Name of the storage account. Must be globally unique, lowercase alphanumeric, 3-24 chars.')
param name string

@description('Azure region.')
param location string

@description('Blob containers to create, matching what src/adf and src/databricks expect (raw source files, streaming checkpoints).')
param containerNames array = [
  'raw'
  'checkpoints'
]

param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true // ADLS Gen2 — required by Auto Loader / AzureBlobFS linked service
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [
  for containerName in containerNames: {
    parent: blobService
    name: containerName
  }
]

output id string = storageAccount.id
output name string = storageAccount.name
output primaryDfsEndpoint string = storageAccount.properties.primaryEndpoints.dfs
