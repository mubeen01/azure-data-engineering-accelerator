@description('Name of an existing SQL logical server.')
param sqlServerName string

@description('Name of an existing database on that server.')
param sqlDatabaseName string

@description('Resource ID of the Log Analytics workspace to send logs/metrics to.')
param logAnalyticsWorkspaceId string

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' existing = {
  name: sqlServerName
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' existing = {
  parent: sqlServer
  name: sqlDatabaseName
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-log-analytics'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs' // QueryStoreRuntimeStatistics, Errors, Blocks, Deadlocks, etc.
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Basic' // DTU/CPU/storage percentage — what the alert rule in alerts.bicep watches
        enabled: true
      }
    ]
  }
}
