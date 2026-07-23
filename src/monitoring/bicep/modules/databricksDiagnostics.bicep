@description('Name of an existing Databricks workspace.')
param databricksWorkspaceName string

@description('Resource ID of the Log Analytics workspace to send logs/metrics to.')
param logAnalyticsWorkspaceId string

resource workspace 'Microsoft.Databricks/workspaces@2023-02-01' existing = {
  name: databricksWorkspaceName
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-log-analytics'
  scope: workspace
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs' // clusters, jobs, notebook, DBFS, SSH, Unity Catalog access, etc.
        enabled: true
      }
    ]
  }
}
