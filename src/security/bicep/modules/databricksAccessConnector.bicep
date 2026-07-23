@description('Name of the Databricks Access Connector.')
param name string

@description('Azure region.')
param location string

param tags object = {}

// The Azure-native identity Unity Catalog storage credentials authenticate
// with — not a generic user-assigned identity. Grant this connector's
// identity Storage Blob Data Contributor (storageRoleAssignment.bicep) on
// the lake, then reference this resource's ID from a
// databricks_storage_credential (Terraform databricks provider — no Bicep
// equivalent exists for that Unity Catalog-side object).
resource accessConnector 'Microsoft.Databricks/accessConnectors@2023-05-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
}

output id string = accessConnector.id
output principalId string = accessConnector.identity.principalId
