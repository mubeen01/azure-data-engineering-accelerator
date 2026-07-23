# Security

Adds the security layer on top of what `src/infrastructure/` already
provisioned. Deploy **after** `src/infrastructure/`, into the same resource
group. Doesn't duplicate the RBAC `src/infrastructure/` already grants ADF
(Storage Blob Data Contributor, Key Vault Secrets User) — that stays there,
scoped to exactly what ADF needs.

Available in both Bicep and Terraform, kept functionally identical, except
where noted below.

## What this adds

- **SQL Entra ID admin** — sets an Entra user or (better) group as a second,
  human-facing admin path on the SQL server. Additive: SQL authentication
  (the admin login + Key Vault-stored password `src/infrastructure/` set up
  for ADF's linked service) keeps working alongside it.
- **A shared user-assigned managed identity** — for auth scenarios that
  aren't "one resource's own system-assigned identity": a CI/CD pipeline
  using federated credentials, or other future automation. Granted
  `Storage Blob Data Reader` on the storage account as a representative
  example — read-only, since ADF already holds write access separately.
- **A Databricks Access Connector** — the Azure-native identity Unity
  Catalog storage credentials authenticate with (not the generic shared
  identity above — Unity Catalog specifically requires this resource
  type). Granted `Storage Blob Data Contributor` on the storage account,
  since Unity Catalog needs to write managed tables, not just read.
- **An Entra ID app registration for CI/CD** (Terraform only, opt-in via
  `enable_cicd_app`) — app registration + service principal + a GitHub
  Actions OIDC federated credential, granted `Contributor` on the resource
  group `src/infrastructure/` created. No client secret is ever generated;
  GitHub authenticates via OIDC token exchange instead.

`storageRoleAssignment.bicep` / `storage_role_assignment` (Terraform) is
one generic module used for both the reader and contributor grants above —
pass `role`/`role_definition_name` to pick which.

## Why the CI/CD app registration is Terraform-only

Bicep/ARM has no stable native resource for Entra ID objects — the
Microsoft Graph Bicep extension exists but is marked retired in favor of a
newer dynamic-types mechanism that this Bicep CLI version (0.45) doesn't
support cleanly (`az bicep build` failed on `extension microsoftGraph`
directly during development of this module). Terraform's `azuread`
provider is mature and validated cleanly, so app registration lives there
only. If you're a Bicep-only shop, the equivalent is a short `az ad app
create` / `az ad app federated-credential create` script instead.

## Why Unity Catalog's storage credential itself isn't built here

`azurerm_databricks_access_connector` (this repo's contribution) is the
Azure-side identity. The Unity Catalog-side objects that reference it
(`databricks_storage_credential`, `databricks_external_location`) come from
the separate `databricks` Terraform provider, and assume a Unity Catalog
metastore is already assigned to the workspace — that's normally a
one-time, per-region/per-organization setup done outside any single
project's deployment, not something to provision speculatively here.
Wiring those two resources in is a few lines once a real metastore exists;
premature before that.

## Deploy

Bicep:

```bash
az deployment group create \
  --resource-group rg-adea-dev \
  --template-file bicep/main.bicep \
  --parameters location=eastus2 sqlServerName=<...> storageAccountName=<...> \
               entraAdminLogin='adea-dba' entraAdminObjectId='<entra-group-object-id>'
```

Terraform:

```bash
cd terraform
terraform init
terraform apply \
  -var="resource_group_name=rg-adea-dev" -var="location=eastus2" \
  -var="sql_server_name=<...>" -var="storage_account_name=<...>" \
  -var="entra_admin_login=adea-dba" -var="entra_admin_object_id=<entra-group-object-id>"

# Optionally, to also create the CI/CD app registration:
terraform apply \
  -var="enable_cicd_app=true" \
  -var="github_federated_subject=repo:my-org/my-repo:ref:refs/heads/main" \
  ... (plus the required vars above)
```

## A known trade-off, not an oversight

`terraform validate` flags the SQL Entra admin resource
(`azurerm_sql_active_directory_administrator`) as deprecated: azurerm 4.x
replaces it with an `azuread_administrator` block nested inside the
`azurerm_mssql_server` resource itself. That block can only be set where
the server is actually defined — `src/infrastructure/terraform` — not
bolted on from a separate security config. Migrating means moving this
concern across the Phase 6/7 boundary, not just renaming a resource, so
it's deferred until this repo actually upgrades off azurerm 3.x. See the
comment in `terraform/modules/sql_entra_admin/main.tf`.

## Status

Offline-validated only (`az bicep build`, `terraform validate` — both
clean, one documented deprecation warning above) — not deployed against a
real subscription.
