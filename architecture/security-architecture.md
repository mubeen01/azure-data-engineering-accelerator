# Security Architecture

The security decisions made throughout this repo, gathered in one place.
None of this was bolted on at the end — Managed Identity and Key Vault
were designed in from Phase 4 (`src/adf/`) onward; `src/security/` (Phase
7) adds the pieces that needed a live tenant/subscription context rather
than introducing a different model.

## Identity, not secrets, is the default

| Identity | Type | What it can do |
|---|---|---|
| Data Factory | System-assigned managed identity | `Storage Blob Data Contributor` on the lake, `Key Vault Secrets User` on the vault — set up in `src/infrastructure/bicep/modules/rbac.bicep` / `terraform/modules/rbac` |
| Databricks Access Connector | System-assigned managed identity | `Storage Blob Data Contributor` — the Azure-native identity Unity Catalog storage credentials authenticate with (`src/security/`) |
| Shared user-assigned identity | User-assigned managed identity | `Storage Blob Data Reader` — a template for future consumers (CI/CD, other automation) that aren't tied to one resource's own identity |
| CI/CD app registration (opt-in) | Entra ID app + federated credential | `Contributor` on the resource group only — scoped to what a deployment pipeline needs, nothing subscription-wide |

The one credential that does exist — the SQL admin password
(`src/infrastructure/`) — is `@secure()`/`sensitive` at deploy time and
immediately written into Key Vault as a secret
(`src/infrastructure/bicep/modules/keyVaultSecret.bicep`), never left in
plaintext state or parameters beyond that single write.

## Why SQL keeps password authentication at all

ADF's linked service (`src/adf/linkedService/ls_AdeaDW_AzureSqlDatabase.json`)
uses SQL authentication with the password sourced from Key Vault, not
Managed Identity — because wiring Azure AD-only authentication through to
an ADF linked service needs additional AAD admin configuration on the SQL
server that's a bigger lift than this accelerator's scope. `src/security/`
adds an Entra ID admin on the SQL server as a *second*, human-facing path
(`sqlEntraAdmin.bicep` / `modules/sql_entra_admin`) — additive, not a
replacement. A team that wants to go further and drop SQL auth entirely
can build on that Entra admin, but it isn't done here.

## Key Vault: RBAC, not access policies

`enableRbacAuthorization: true` throughout — deliberately not the older
access-policy model. One consequence worth knowing before deploying:
**the identity running the deployment itself** needs `Key Vault Secrets
Officer` (or higher) to write the SQL password secret — RBAC mode doesn't
implicitly grant the deployer that access the way access policies
sometimes appeared to. See `src/security/README.md` and
`src/infrastructure/README.md` for this as a stated prerequisite, not a
surprise.

## Least-privilege scoping

Every RBAC assignment in this repo is scoped to the smallest object that
makes sense — a specific storage account, a specific Key Vault, a specific
resource group — never subscription-wide, and roles are picked for what's
actually needed:

- `Storage Blob Data Contributor` where something writes (ADF, the
  Databricks Access Connector for Unity Catalog).
- `Storage Blob Data Reader` where something only consumes (the shared
  identity's example grant).
- `Contributor` on a resource group, not `Owner` or a subscription-level
  role, for the CI/CD app registration.

## CI/CD auth: OIDC, not stored secrets

The opt-in Entra app registration (`src/security/terraform/modules/entra_cicd_app`)
uses a GitHub Actions federated identity credential
(`azuread_application_federated_identity_credential`) — GitHub exchanges
its own OIDC token for an Azure access token at pipeline-run time. No
client secret is ever generated, stored, or rotated. This is why the
module is Terraform-only right now: Bicep/ARM has no stable native
resource for Entra ID app objects (the Microsoft Graph Bicep extension is
retired in the CLI version this repo was built against — confirmed by
testing it directly, not assumed; see `src/security/README.md`).

## A known, documented trade-off

Terraform's SQL Entra admin resource
(`azurerm_sql_active_directory_administrator`) is deprecated as of azurerm
4.x, which moves the equivalent configuration into an `azuread_administrator`
block nested inside the `azurerm_mssql_server` resource itself. That block
can only be set where the server is actually defined
(`src/infrastructure/terraform`), not from `src/security/terraform` — so
the migration is a real move across the Phase 6/7 boundary, not a
find-and-replace. Deferred until this repo upgrades off azurerm 3.x; see
the comment in `src/security/terraform/modules/sql_entra_admin/main.tf`.

## What's deliberately not built

- The Unity Catalog-side objects that would consume the Databricks Access
  Connector (`databricks_storage_credential`, `databricks_external_location`)
  — those need a Unity Catalog metastore already assigned to the
  workspace, normally a one-time per-region/per-organization setup done
  outside any single project's deployment.
- Detailed alert-on-security-event wiring (e.g. alerting on Key Vault
  `AuditEvent` logs specifically) — the diagnostic settings send those
  logs to Log Analytics (`src/monitoring/`), but no alert rule watches
  them yet; the two alerts that exist (`src/monitoring/`) are operational
  (ADF failures, SQL DTU), not security-specific.
