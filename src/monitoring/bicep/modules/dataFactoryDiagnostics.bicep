@description('Name of an existing Data Factory.')
param dataFactoryName string

@description('Resource ID of the Log Analytics workspace to send logs/metrics to.')
param logAnalyticsWorkspaceId string

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-log-analytics'
  scope: dataFactory
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs' // PipelineRuns, ActivityRuns, TriggerRuns — what audit.log_etl_run doesn't capture (ADF-level retries/queueing)
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
