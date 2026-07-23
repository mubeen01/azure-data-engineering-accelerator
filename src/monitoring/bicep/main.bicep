// Resource-group-scoped: deploy this AFTER src/infrastructure/bicep/main.bicep
// — it wires diagnostic settings + alerts onto resources that already exist,
// it doesn't create them. Deploy into the same resource group
// (rg-adea-<environment>) src/infrastructure/ created.

@description('Log Analytics workspace name from the src/infrastructure deployment.')
param logAnalyticsWorkspaceName string

@description('Storage account name from the src/infrastructure deployment.')
param storageAccountName string

@description('Key Vault name from the src/infrastructure deployment.')
param keyVaultName string

@description('SQL server name from the src/infrastructure deployment.')
param sqlServerName string

@description('SQL database name from the src/infrastructure deployment.')
param sqlDatabaseName string = 'AdeaDW'

@description('Data Factory name from the src/infrastructure deployment.')
param dataFactoryName string

@description('Databricks workspace name from the src/infrastructure deployment.')
param databricksWorkspaceName string

@description('Email address for alert notifications.')
param notificationEmail string

param tags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' existing = {
  name: sqlServerName
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' existing = {
  parent: sqlServer
  name: sqlDatabaseName
}

module storageDiagnostics 'modules/storageDiagnostics.bicep' = {
  name: 'storageDiagnostics'
  params: {
    storageAccountName: storageAccountName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
  }
}

module keyVaultDiagnostics 'modules/keyVaultDiagnostics.bicep' = {
  name: 'keyVaultDiagnostics'
  params: {
    keyVaultName: keyVaultName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
  }
}

module sqlDatabaseDiagnostics 'modules/sqlDatabaseDiagnostics.bicep' = {
  name: 'sqlDatabaseDiagnostics'
  params: {
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
  }
}

module dataFactoryDiagnostics 'modules/dataFactoryDiagnostics.bicep' = {
  name: 'dataFactoryDiagnostics'
  params: {
    dataFactoryName: dataFactoryName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
  }
}

module databricksDiagnostics 'modules/databricksDiagnostics.bicep' = {
  name: 'databricksDiagnostics'
  params: {
    databricksWorkspaceName: databricksWorkspaceName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
  }
}

module alerts 'modules/alerts.bicep' = {
  name: 'alerts'
  params: {
    notificationEmail: notificationEmail
    dataFactoryId: dataFactory.id
    sqlDatabaseId: sqlDatabase.id
    tags: tags
  }
}
