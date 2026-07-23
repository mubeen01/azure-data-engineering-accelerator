@description('Name of the Log Analytics workspace.')
param name string

@description('Azure region.')
param location string

@description('Retention period in days.')
param retentionInDays int = 30

param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
  }
}

output id string = workspace.id
output name string = workspace.name
