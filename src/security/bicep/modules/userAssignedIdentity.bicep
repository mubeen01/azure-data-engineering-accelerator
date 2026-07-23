@description('Name of the user-assigned managed identity.')
param name string

@description('Azure region.')
param location string

param tags object = {}

// A shared identity for scenarios that aren't "one resource's own system-
// assigned identity" and aren't Unity Catalog specifically (that's
// databricksAccessConnector.bicep) — e.g. a CI/CD pipeline authenticating
// via federated credentials instead of a stored secret. Granted storage
// read access via storageRoleAssignment.bicep as a representative example;
// grant it further roles as each new need materializes.
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

output id string = identity.id
output principalId string = identity.properties.principalId
output clientId string = identity.properties.clientId
