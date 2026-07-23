# Infrastructure as Code

Provisions the Azure resources that `src/sql/`, `src/adf/`, and
`src/databricks/` target — in both Bicep and Terraform, kept functionally
identical (same 7 resources, same names, same auth model) so either can be
used without the other falling out of date.

Both have been **validated offline** (`az bicep build`, `terraform init` +
`validate`) — both compile/plan-validate cleanly. Neither has been
**deployed** against a real Azure subscription; that's the one open item
before treating this as proven, not just reviewed.

## What gets provisioned

| Resource | Purpose |
|---|---|
| Resource Group | `rg-adea-<environment>` |
| Storage Account (ADLS Gen2) | `raw` + `checkpoints` containers — source for `src/adf/` and `src/databricks/` Auto Loader |
| Key Vault | RBAC-authorized; holds the SQL admin password |
| Azure SQL Server + `AdeaDW` Database | Target for `src/sql/` |
| Data Factory | System-assigned Managed Identity — runs `src/adf/` pipelines |
| Databricks Workspace | Premium SKU — runs `src/databricks/` notebooks |
| Log Analytics Workspace | The "Monitor" piece of Phase 6; alerting/diagnostic settings are Phase 7 |

## Auth model (matches `src/adf/README.md`)

- Data Factory gets Storage Blob Data Contributor + Key Vault Secrets User
  via RBAC role assignments — no connection strings or account keys stored
  anywhere.
- The SQL admin password is a `@secure()`/`sensitive` parameter at deploy
  time, immediately written into Key Vault as a secret, never left in
  plaintext state/parameters beyond that.

## What Phase 7 still has to do

- Alert rules, diagnostic settings wiring resources into the Log Analytics
  workspace, and any RBAC beyond what ADF's identity needs (e.g. human
  access, Databricks-to-storage Unity Catalog credentials).
- Microsoft Entra ID app registrations / Entra-only SQL auth, if you want to
  move off SQL authentication entirely.

## Deploy with Bicep

```bash
az deployment sub create \
  --location eastus2 \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters/main.dev.parameters.json \
  --parameters sqlAdminPassword='<a-real-password>'
```

`sqlAdminPassword` is deliberately left as a placeholder in the checked-in
parameters file — pass the real value on the command line or via a
pipeline secret, never commit it.

## Deploy with Terraform

```bash
cd terraform
terraform init
terraform plan -var-file=terraform.tfvars.example -var="sql_admin_password=<a-real-password>"
terraform apply -var-file=terraform.tfvars.example -var="sql_admin_password=<a-real-password>"
```

Copy `terraform.tfvars.example` to `terraform.tfvars` for your own
environment values (it's gitignored); keep `sql_admin_password` out of any
committed `.tfvars` file — use `-var`, `TF_VAR_sql_admin_password`, or your
pipeline's secret store.

**Prerequisite:** because the Key Vault uses RBAC authorization, whoever
runs `terraform apply` (or the Bicep deployment) needs "Key Vault Secrets
Officer" (or higher) on the vault themselves, or the SQL password secret
write will fail with a permissions error — this is a one-time role
assignment outside of what these templates provision for you.

## Folder structure

```text
bicep/
  main.bicep              Subscription-scope entry point
  modules/                One file per resource
  parameters/main.dev.parameters.json
terraform/
  providers.tf, main.tf, variables.tf, outputs.tf
  modules/                One folder per resource, mirrors bicep/modules/
  terraform.tfvars.example
```
