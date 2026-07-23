# Additive, not a replacement: src/infrastructure/ provisions SQL
# authentication (admin login + Key Vault-stored password) for ADF's linked
# service. This adds an Entra identity (ideally a group, e.g. "adea-dba")
# as a second, human-facing admin path — it doesn't disable SQL auth.
#
# azurerm has no "azurerm_mssql_*"-prefixed standalone Entra admin resource
# for a regular (non-managed-instance) server — azurerm_sql_active_directory_administrator
# is the provider's legacy-named but still-current-on-3.x resource for
# exactly this, and works against a server created via azurerm_mssql_server
# since both target the same underlying Microsoft.Sql/servers ARM resource.
#
# `terraform validate` flags this as deprecated: azurerm 4.x removes it in
# favor of an `azuread_administrator` block nested inside the
# `azurerm_mssql_server` resource itself. That block can only be set where
# the server resource is actually defined (src/infrastructure/terraform),
# not bolted on from here — so migrating means moving this concern across
# the Phase 6/7 boundary, not just swapping the resource name. Deferred
# until this repo actually upgrades off azurerm 3.x.
resource "azurerm_sql_active_directory_administrator" "this" {
  server_name         = var.sql_server_name
  resource_group_name = var.resource_group_name
  login               = var.entra_admin_login
  object_id           = var.entra_admin_object_id
  tenant_id           = var.tenant_id
}
