// Subscription-scope entry point: creates the resource group, then deploys
// every resource into it. Provisions the containers referenced by
// src/adf/ and src/databricks/ (storage, Key Vault, SQL, Data Factory,
// Databricks, Log Analytics) — it does not configure the detailed
// security/monitoring policy on top of them (RBAC assignments beyond what
// ADF's identity needs, alert rules, Entra app registrations); that's
// Phase 7.
targetScope = 'subscription'

@description('Short environment name, e.g. dev/test/prod — used to build resource names.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string = 'dev'

@description('Azure region for every resource.')
param location string = 'eastus2'

@description('SQL authentication admin login for the AdeaDW server.')
param sqlAdminLogin string = 'adeaadmin'

@secure()
@description('SQL authentication admin password for the AdeaDW server. No default — must be supplied at deploy time.')
param sqlAdminPassword string

@description('Enable Key Vault purge protection. Recommended true outside of throwaway dev environments.')
param enableKeyVaultPurgeProtection bool = false

var tags = {
  project: 'azure-data-engineering-accelerator'
  environment: environmentName
}

// uniqueString() keeps globally-unique resource names (storage, Key Vault,
// SQL server) short and deterministic per subscription+environment, so
// re-running this deployment doesn't generate new names each time.
var uniqueSuffix = uniqueString(subscription().id, environmentName)

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-adea-${environmentName}'
  location: location
  tags: tags
}

module logAnalytics 'modules/logAnalytics.bicep' = {
  name: 'logAnalytics'
  scope: rg
  params: {
    name: 'log-adea-${environmentName}'
    location: location
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: 'stadea${uniqueSuffix}'
    location: location
    tags: tags
  }
}

module keyVault 'modules/keyVault.bicep' = {
  name: 'keyVault'
  scope: rg
  params: {
    name: 'kv-adea-${uniqueSuffix}'
    location: location
    enablePurgeProtection: enableKeyVaultPurgeProtection
    tags: tags
  }
}

module sqlDatabase 'modules/sqlDatabase.bicep' = {
  name: 'sqlDatabase'
  scope: rg
  params: {
    serverName: 'sql-adea-${uniqueSuffix}'
    location: location
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    tags: tags
  }
}

module dataFactory 'modules/dataFactory.bicep' = {
  name: 'dataFactory'
  scope: rg
  params: {
    name: 'adf-adea-${environmentName}'
    location: location
    tags: tags
  }
}

module databricks 'modules/databricks.bicep' = {
  name: 'databricks'
  scope: rg
  params: {
    name: 'dbw-adea-${environmentName}'
    location: location
    managedResourceGroupName: 'rg-adea-${environmentName}-databricks'
    tags: tags
  }
}

// ADF's system-assigned identity needs Storage Blob Data Contributor +
// Key Vault Secrets User — see src/adf/README.md's auth model.
module rbac 'modules/rbac.bicep' = {
  name: 'rbac'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    keyVaultName: keyVault.outputs.name
    principalId: dataFactory.outputs.principalId
  }
}

// Stores the SQL admin password as the secret ls_AdeaDW_AzureSqlDatabase.json references.
module sqlPasswordSecret 'modules/keyVaultSecret.bicep' = {
  name: 'sqlPasswordSecret'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'adea-dw-sql-password'
    secretValue: sqlAdminPassword
  }
}

output resourceGroupName string = rg.name
output storageAccountName string = storage.outputs.name
output storageDfsEndpoint string = storage.outputs.primaryDfsEndpoint
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri
output sqlServerFqdn string = sqlDatabase.outputs.sqlServerFqdn
output sqlDatabaseName string = sqlDatabase.outputs.databaseName
output dataFactoryName string = dataFactory.outputs.name
output databricksWorkspaceUrl string = databricks.outputs.workspaceUrl
output logAnalyticsWorkspaceName string = logAnalytics.outputs.name
