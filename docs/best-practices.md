# Best Practices

Practices this repo actually follows, gathered in one place for anyone
extending it. Each one is grounded in a real file, not aspirational — if
you add a new object/pipeline/notebook/module, matching these keeps it
consistent with everything already here. Naming specifics live in
`docs/naming-conventions.md`; language-level style rules live in
`docs/coding-standards.md`. This page is about *design* decisions.

## Extend the generic framework, don't fork it

`src/` holds the reusable pattern; `examples/<industry>/` holds what's
genuinely industry-specific, layered on top via foreign keys, not copies.
Banking's `dim_account`/`dim_loan` reference the generic `dim_customer` by
FK rather than redefining customer; its fact-loading notebook does an
extra join to resolve `customer_key` through `dim_account` rather than
modifying the generic Gold notebook to special-case banking. Before adding
logic to `src/`, ask whether it's true for every industry — if not, it
belongs in `examples/`. See `architecture/medallion-architecture.md`'s
"Facts" section for the worked example.

## Metadata-driven over hand-built

Adding a new source object to the ADF framework means inserting a row into
`etl.ctrl_pipeline_metadata`, not authoring a new pipeline. This is why
`src/adf/pipeline/` has exactly four files regardless of how many source
objects exist. The same instinct applies to the Databricks Bronze/Gold
SCD notebooks — they're driven by widget parameters, not one notebook per
table.

## Idempotency, everywhere

- SQL: every script is safely re-runnable — existence checks before
  create/drop, `CREATE OR ALTER` for procedures/views/functions, `MERGE`
  or an existence check instead of a bare `INSERT` for seed data (details:
  `src/sql/00-standards/sql-coding-standards.md`).
- ADF full loads: truncate-then-copy, not append, so a re-run doesn't
  double-load.
  ADF incremental loads: watermark-gated, so a re-run without new data is
  a no-op.
- Databricks: every load is a `MERGE`, not an `INSERT` — SCD1, SCD2, and
  fact loads are all safe to run twice on the same batch.

If you write a load path that isn't safe to re-run, that's a bug, not a
stylistic choice.

## Identity over secrets

Every credential in this repo defaults to a managed identity with a
scoped RBAC role, not a connection string or access key: Data Factory's
storage access is its system-assigned identity with `Storage Blob Data
Contributor`, the Databricks Access Connector authenticates Unity
Catalog's storage credential the same way, and CI/CD auth (the opt-in
Entra app registration) uses GitHub's OIDC federated credential rather
than a stored client secret. The one exception — SQL authentication for
ADF's database linked service — is a deliberate, documented tradeoff
(wiring AAD-only auth through an ADF linked service is a bigger lift than
this accelerator's scope), and even that password never sits in plaintext
config: it's written straight into Key Vault at deploy time. See
`architecture/security-architecture.md`.

## Least-privilege RBAC scoping

Every role assignment targets the smallest object that makes sense — a
specific storage account or Key Vault, not the subscription — and the
role itself is picked for what's actually needed (`Storage Blob Data
Reader` for something that only consumes, `Contributor` on a resource
group rather than `Owner` for the CI/CD app registration). Don't widen a
scope "to be safe" — narrow it to what the consuming identity actually
does.

## Keep Bicep and Terraform functionally identical, not code-identical

Both IaC implementations provision the same 7-ish resources with the same
names and the same auth model, but each is written idiomatically for its
own tool (Bicep: one small typed module per resource type, because
`scope:` needs a real resource symbol, not an arbitrary `resourceId()`
string; Terraform: some modules are more generic, because
`target_resource_id` is just a string there). When adding a resource to
one, add the equivalent to the other in the same change — a Bicep-only or
Terraform-only capability silently makes one implementation stale. The one
sanctioned exception today is the CI/CD Entra app registration, which is
Terraform-only for a documented reason (Bicep's Microsoft Graph extension
is retired) — call out any similar exception explicitly, don't let it go
unstated.

## Validate to the ceiling the environment allows, and say so

Every module in this repo states its actual verification status rather
than implying more than what's been checked: "compiles/plans cleanly,
never deployed," "notebook syntax valid, never run against a cluster," or
"verified against a real, live SQL Server 2022 container." `CHANGELOG.md`
and `ROADMAP.md` distinguish **Verified** (ran against something real)
from **Added** (written and reviewed) as separate sections — keep using
that distinction rather than collapsing "written" into "done." CI
(`.github/workflows/ci.yml`) automates exactly this ceiling per module —
Bicep/Terraform offline validation, JSON well-formedness, Python syntax
plus one live smoke test (the generator), and one live-service-container
test (SQL Server) — extend it rather than adding a parallel manual check
when you add a new module.

## Prefer the portable pattern when engines diverge

SCD Type 2 loads use expire-then-insert (`UPDATE` then `INSERT`) rather
than `MERGE` in the SQL framework specifically so the same procedure works
unmodified on Synapse dedicated pools, where `MERGE` isn't supported — SCD
Type 1 uses `MERGE` because there's no such constraint on an overwrite-only
load. When a target platform has a real, documented capability gap
(`src/sql/00-standards/sql-coding-standards.md`'s compatibility table),
default to the pattern that works everywhere rather than the shortest one
for a single platform, and note the tradeoff in a comment.

## Every module ships its own README

Every folder under `src/`, `tools/`, and `examples/` documents itself —
purpose, folder structure, how it connects to neighboring modules, and
what's explicitly not done yet. `docs/` and `architecture/` are the
cross-cutting layer on top of that, not a replacement for it. If you add a
module, its README is part of the deliverable, not a follow-up.
