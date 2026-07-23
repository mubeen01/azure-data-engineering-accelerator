# Architecture

This is a map, not a duplicate — the detailed design docs live in
`architecture/` and are the source of truth. This page exists so someone
landing in `docs/` doesn't have to already know that folder exists.

## The three-layer split

```text
src/          Generic, reusable framework — not tied to any one industry
examples/     End-to-end industry accelerators, built on top of src/
docs/, architecture/   Documentation — this folder is orientation/reference,
                       architecture/ is the detailed design record
```

`src/` never contains industry-specific logic. When an industry needs
something the generic framework doesn't provide — banking's `dim_account`/
`dim_loan`, or resolving `customer_key` through an intermediate table — that
lives in `examples/<industry>/`, layered on top via foreign keys or
inheritance, not by editing `src/` in place. `examples/banking/` is the one
industry this has actually been proven for end-to-end; see
`examples/banking/README.md` for the two real mismatches that pattern had
to reconcile.

## Two engines, one model

`src/sql/` (T-SQL star schema) and `src/databricks/` (Delta Lake notebooks)
implement the *same* dimensional model — same table names, same columns,
same SCD semantics — as two independent engines rather than one depending
on the other. A team can run the SQL path, the Databricks path, or both.
`src/fabric/` and `src/synapse/` are adaptations of these same two engines
to two more Microsoft compute surfaces (Fabric Lakehouse notebooks adapt
the Databricks path; Fabric Warehouse and Synapse serverless SQL adapt the
SQL path), not a third independent design.

Full detail: `architecture/medallion-architecture.md` (the Bronze/Silver/
Gold pattern in both engines, where they deliberately diverge, and why).

## How data moves

```text
Source data → Bronze (raw, as-ingested) → Silver (cleansed/conformed)
            → Gold (star schema: dim_*, fact_*) → reporting / BI

Orchestration:
  src/adf/pl_master_orchestrator → per-object full or incremental load,
  driven by etl.ctrl_pipeline_metadata (src/sql/), not per-object pipelines
```

The ADF framework is metadata-driven on purpose — see `src/adf/README.md`
for why one generic pipeline pair plus a control table replaces
hand-building a pipeline per source object, and how `load_priority`
guarantees dimensions load before the facts that reference them.

## What gets deployed, and in what order

`src/infrastructure/` provisions resources; `src/monitoring/` and
`src/security/` configure observability and access control on top of
those resources rather than creating anything new — three separate
deployments so that changing an alert threshold never risks the
underlying storage account or database. Both Bicep and Terraform
implementations are kept functionally identical.

Full detail: `architecture/deployment-architecture.md` (exact resource
topology, naming, and the six-step deploy order) and
`architecture/security-architecture.md` (the identity/RBAC model —
Managed Identity by default, Key Vault RBAC not access policies,
OIDC for CI/CD rather than stored secrets).

## Read next

1. `architecture/overview.md` — architecture principles and core Azure
   components.
2. `architecture/medallion-architecture.md` — Bronze/Silver/Gold in detail.
3. `architecture/deployment-architecture.md` — provisioning order and
   resource topology.
4. `architecture/security-architecture.md` — identity and RBAC end to end.
5. `docs/best-practices.md` and `docs/coding-standards.md` — the
   conventions that keep both engines' implementations consistent with
   each other.

## Verification status

Design intent and implementation match as far as offline validation can
confirm (`az bicep build`, `terraform validate`, `python -m py_compile`,
JSON well-formedness — all in CI) plus one partial live-database run (SQL
Server 2022 in Docker, database/schemas/dimensions only — see
`CHANGELOG.md`). No part of this architecture has been proven against a
real Azure subscription end-to-end yet — see `ROADMAP.md`'s
"genuinely open threads" for what that would surface next.
