@description('Name of the Data Factory.')
param name string

@description('Azure region.')
param location string

param tags object = {}

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned' // src/adf/README.md's auth model relies on this for storage + Key Vault access
  }
  properties: {}
}

output id string = dataFactory.id
output name string = dataFactory.name
output principalId string = dataFactory.identity.principalId
