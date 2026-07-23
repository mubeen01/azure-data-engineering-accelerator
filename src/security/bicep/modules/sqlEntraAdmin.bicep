@description('Name of an existing SQL logical server.')
param sqlServerName string

@description('Display name of the Entra ID user/group to set as SQL admin.')
param entraAdminLogin string

@description('Object ID of the Entra ID user/group.')
param entraAdminObjectId string

@description('Entra tenant ID.')
param tenantId string = subscription().tenantId

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' existing = {
  name: sqlServerName
}

// Additive, not a replacement: src/infrastructure/ provisions SQL
// authentication (admin login + Key Vault-stored password) for ADF's linked
// service. This adds an Entra identity (ideally a group, e.g. "adea-dba")
// as a second, human-facing admin path — it doesn't disable SQL auth.
resource entraAdmin 'Microsoft.Sql/servers/administrators@2021-11-01' = {
  parent: sqlServer
  name: 'ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: entraAdminLogin
    sid: entraAdminObjectId
    tenantId: tenantId
  }
}
