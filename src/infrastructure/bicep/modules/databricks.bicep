@description('Name of the Databricks workspace.')
param name string

@description('Azure region.')
param location string

@description('Name for the separate resource group Databricks manages internally (must not already exist — Azure creates it during provisioning).')
param managedResourceGroupName string

@allowed([
  'trial'
  'standard'
  'premium'
])
@description('premium unlocks RBAC/cluster policies/Unity Catalog-related features used by src/databricks/.')
param skuName string = 'premium'

param tags object = {}

resource workspace 'Microsoft.Databricks/workspaces@2023-02-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    managedResourceGroupId: '${subscription().id}/resourceGroups/${managedResourceGroupName}'
  }
}

output id string = workspace.id
output name string = workspace.name
output workspaceUrl string = workspace.properties.workspaceUrl
