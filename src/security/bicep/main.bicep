// Resource-group-scoped: deploy this AFTER src/infrastructure/bicep/main.bicep,
// into the same resource group (rg-adea-<environment>). Adds the security
// layer on top of what that deployment already created — it doesn't
// duplicate the RBAC that src/infrastructure already grants ADF.

@description('Azure region for the new shared managed identity.')
param location string

@description('SQL server name from the src/infrastructure deployment.')
param sqlServerName string

@description('Display name of the Entra ID user/group to set as SQL admin (ideally a group, e.g. "adea-dba").')
param entraAdminLogin string

@description('Object ID of that Entra ID user/group.')
param entraAdminObjectId string

@description('Storage account name from the src/infrastructure deployment.')
param storageAccountName string

@description('Short environment name — used to name the shared managed identity.')
param environmentName string = 'dev'

param tags object = {}

module sqlEntraAdmin 'modules/sqlEntraAdmin.bicep' = {
  name: 'sqlEntraAdmin'
  params: {
    sqlServerName: sqlServerName
    entraAdminLogin: entraAdminLogin
    entraAdminObjectId: entraAdminObjectId
  }
}

module sharedIdentity 'modules/userAssignedIdentity.bicep' = {
  name: 'sharedIdentity'
  params: {
    name: 'id-adea-shared-${environmentName}'
    location: location
    tags: tags
  }
}

module sharedIdentityStorageAccess 'modules/storageRoleAssignment.bicep' = {
  name: 'sharedIdentityStorageAccess'
  params: {
    storageAccountName: storageAccountName
    principalId: sharedIdentity.outputs.principalId
    role: 'StorageBlobDataReader'
  }
}

// Unity Catalog's Azure-native auth path: grant the connector's identity
// write access, then reference accessConnector.outputs.id from a
// databricks_storage_credential (Terraform databricks provider — see
// src/security/terraform/modules/entra_cicd_app's README note; Bicep/ARM
// has no resource for that Unity Catalog-side object).
module databricksAccessConnector 'modules/databricksAccessConnector.bicep' = {
  name: 'databricksAccessConnector'
  params: {
    name: 'dbac-adea-${environmentName}'
    location: location
    tags: tags
  }
}

module databricksAccessConnectorStorageAccess 'modules/storageRoleAssignment.bicep' = {
  name: 'databricksAccessConnectorStorageAccess'
  params: {
    storageAccountName: storageAccountName
    principalId: databricksAccessConnector.outputs.principalId
    role: 'StorageBlobDataContributor'
  }
}

output sharedIdentityId string = sharedIdentity.outputs.id
output sharedIdentityClientId string = sharedIdentity.outputs.clientId
output databricksAccessConnectorId string = databricksAccessConnector.outputs.id
