@description('Logical SQL server name. Must be globally unique.')
param serverName string

@description('Azure region.')
param location string

@description('Database name — must match src/sql/01-database/01_Create_Database.sql.')
param databaseName string = 'AdeaDW'

@description('SQL authentication admin login.')
param sqlAdminLogin string

@secure()
@description('SQL authentication admin password.')
param sqlAdminPassword string

@description('Database SKU. Basic/S0 is a cheap default for a dev/accelerator environment — size up for anything real.')
param skuName string = 'Basic'

@description('Allow Azure services (ADF, Databricks) to reach this server. Fine for a dev environment; tighten with private endpoints for anything real.')
param allowAzureServices bool = true

param tags object = {}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: serverName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource allowAzureServicesRule 'Microsoft.Sql/servers/firewallRules@2021-11-01' = if (allowAzureServices) {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource database 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlServerName string = sqlServer.name
output databaseName string = database.name
