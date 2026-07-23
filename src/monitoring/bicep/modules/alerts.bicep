@description('Email address to notify on alert.')
param notificationEmail string

@description('Resource ID of the Data Factory to alert on.')
param dataFactoryId string

@description('Resource ID of the SQL database to alert on.')
param sqlDatabaseId string

param tags object = {}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-adea-ops'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'adeaOps'
    enabled: true
    emailReceivers: [
      {
        name: 'primary-email'
        emailAddress: notificationEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

// Fires on any failed ADF pipeline run — every load procedure already logs
// to audit.log_etl_run (src/sql), but this is the "someone should look at
// this now" layer on top, independent of anyone querying that table.
resource adfPipelineFailuresAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-adf-pipeline-failures'
  location: 'global'
  tags: tags
  properties: {
    severity: 2
    enabled: true
    scopes: [
      dataFactoryId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'PipelineFailedRuns'
          metricName: 'PipelineFailedRuns'
          metricNamespace: 'Microsoft.DataFactory/factories'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// DTU-based tiers (Basic/S0 default in src/infrastructure) expose
// dtu_consumption_percent rather than cpu_percent.
resource sqlHighDtuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-sql-high-dtu'
  location: 'global'
  tags: tags
  properties: {
    severity: 3
    enabled: true
    scopes: [
      sqlDatabaseId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighDtuConsumption'
          metricName: 'dtu_consumption_percent'
          metricNamespace: 'Microsoft.Sql/servers/databases'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}
