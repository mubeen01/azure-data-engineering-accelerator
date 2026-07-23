# Monitoring

Wires diagnostic settings and alert rules onto the resources
`src/infrastructure/` already provisioned — it doesn't create those
resources itself, only configures observability on top of them. Deploy
**after** `src/infrastructure/`, into the same resource group.

Available in both Bicep and Terraform, kept functionally identical.

## What gets configured

| Resource | Logs sent to Log Analytics | Metrics |
|---|---|---|
| Storage account | `allLogs` — on the **blob service sub-resource**, not the account itself (blob read/write/delete logs live there) | `Transaction` |
| Key Vault | `allLogs` (includes `AuditEvent` — who read/wrote which secret) | `AllMetrics` |
| SQL Database | `allLogs` (`QueryStoreRuntimeStatistics`, `Errors`, `Blocks`, `Deadlocks`, ...) | `Basic` (DTU/CPU/storage) |
| Data Factory | `allLogs` (`PipelineRuns`, `ActivityRuns`, `TriggerRuns`) | `AllMetrics` |
| Databricks | `allLogs` (clusters, jobs, notebook, DBFS, Unity Catalog access, ...) | — |

Plus one action group (email) and two metric alerts:

- **ADF pipeline failures** — fires on any `PipelineFailedRuns > 0`. Every
  load procedure already logs to `audit.log_etl_run` (`src/sql/`), but
  that only helps if someone queries it; this is the push notification on
  top.
- **SQL high DTU** — fires above 80% DTU consumption (the Basic/S0 default
  tier in `src/infrastructure/` is DTU-based, not vCore, hence
  `dtu_consumption_percent` rather than `cpu_percent`).

## Deploy

Bicep (resource-group scope — deploy into the RG `src/infrastructure/bicep`
created):

```bash
az deployment group create \
  --resource-group rg-adea-dev \
  --template-file bicep/main.bicep \
  --parameters logAnalyticsWorkspaceName=log-adea-dev storageAccountName=<...> \
               keyVaultName=<...> sqlServerName=<...> dataFactoryName=adf-adea-dev \
               databricksWorkspaceName=dbw-adea-dev notificationEmail=<you@example.com>
```

Terraform:

```bash
cd terraform
terraform init
terraform apply \
  -var="resource_group_name=rg-adea-dev" -var="log_analytics_workspace_name=log-adea-dev" \
  -var="storage_account_name=<...>" -var="key_vault_name=<...>" -var="sql_server_name=<...>" \
  -var="data_factory_name=adf-adea-dev" -var="databricks_workspace_name=dbw-adea-dev" \
  -var="notification_email=<you@example.com>"
```

Resource names come from `src/infrastructure/`'s deployment outputs.

## Status

Offline-validated only (`az bicep build`, `terraform validate` — both
clean) — not deployed against a real subscription. Category-group/metric
names (`allLogs`, `Basic`, `AllMetrics`, `dtu_consumption_percent`) are only
checked for HCL/Bicep syntax by these tools, not confirmed against Azure's
live API surface, since that requires an actual deployment.
