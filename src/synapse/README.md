# Azure Synapse Analytics

Was partially covered already (compatibility notes) and deferred the rest
to post-v1.0 — completed now on request. Synapse has three surfaces; each
gets a different treatment here based on how much genuinely differs from
what's already built.

| Synapse surface | Treatment |
|---|---|
| **Dedicated SQL Pool** | Already covered — `src/sql/00-standards/sql-coding-standards.md` has had dedicated-pool compatibility notes (no `MERGE`, no filtered indexes, `NOT ENFORCED` constraints) since Phase 2. Nothing new needed here. |
| **Serverless SQL Pool** | New — `serverless/01_Create_External_Views.sql`. Genuinely distinct from anything else in this repo: queries the Gold Delta layer directly via `OPENROWSET ... FORMAT = 'DELTA'`, no data movement, billed per TB scanned rather than provisioned compute. |
| **Pipelines** | New — `pipelines/pl_synapse_copy_and_transform.json`. Synapse Pipelines share ADF's JSON schema almost exactly (same underlying engine), so the Copy activity ports from `src/adf/` essentially unchanged. The one genuinely different piece is the `SynapseNotebook` activity type (Synapse's own Spark pools, not Databricks). |
| **Spark Pools** | New — `spark/`. Bronze/Silver/Gold adapted from `src/databricks/`, using Synapse's own default Spark metastore (`bronze`/`silver`/`gold` databases) rather than Unity Catalog or Fabric's Lakehouse naming. |

## What's actually new vs. what's a relabeled copy

Be clear-eyed about this: the SCD Type 1/2 and fact merge logic in
`spark/00_common/utils.py` is **identical** to `src/databricks/00_common/utils.py`
— Delta `MERGE` isn't platform-specific. What's genuinely Synapse-specific
is the serverless SQL layer (nothing else in this repo queries a lake
without loading it somewhere first) and the `SynapseNotebook` pipeline
activity type. The rest is the same pattern this repo has used
throughout — the value is in demonstrating the pattern once per engine
that needs its own version, not in pretending each engine required
starting over.

## Verification status

Same caveat as `src/fabric/`: no offline validation tool exists for
Synapse workspace items comparable to `az bicep build`/`terraform
validate`. Notebook Python syntax is confirmed valid; pipeline and view
SQL/JSON is reviewed against Microsoft's documented syntax, not executed
against a live Synapse workspace.

## Not built

- A metadata-driven Synapse orchestrator (mirrors `src/adf/`'s scope
  decision — this repo has one full ADF orchestrator, not a second one
  per adjacent engine).
- IaC (Bicep/Terraform) provisioning an actual Synapse workspace —
  `src/infrastructure/` targets Azure SQL DB, not Synapse; adding a
  Synapse workspace module would be a natural `src/infrastructure/`
  extension, not something that belongs under `src/synapse/` itself.
