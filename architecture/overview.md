# Architecture Overview

ADEA is designed around one idea: a data platform's *pattern* (metadata-driven
ingestion, a medallion lakehouse, a conformed star schema, identity-first
security) should be written once and reused, while the *specifics* of any
one industry or deployment target stay isolated to their own layer. The
three documents that follow this one — `medallion-architecture.md`,
`deployment-architecture.md`, `security-architecture.md` — go deep on each
concern; this page is the vision and the principles behind all three.

## Vision

To be a starting point for building Azure data platforms that's honest
about what "reusable" actually requires: not a single script that claims
to handle every case, but a small set of generic components (control
tables, parameterized pipelines, generic notebooks, a conformed schema)
that industry-specific work builds on rather than forks. See
`docs/faq.md` for what "not production-ready yet" concretely means today.

## Principles

- **Modular** — `src/sql/`, `src/adf/`, `src/databricks/`,
  `src/infrastructure/`, `src/monitoring/`, `src/security/` are
  independently understandable and independently deployable; a team can
  adopt the SQL framework without the Databricks one, or Bicep without
  Terraform.
- **Reusable** — a new source object is a metadata row, not a new
  pipeline; a new dimension is a widget-driven notebook run, not a new
  notebook. See `docs/best-practices.md`'s "metadata-driven over
  hand-built" section.
- **Metadata-driven** — `etl.ctrl_pipeline_metadata` (`src/sql/`) is the
  single source of truth the ADF orchestrator reads from
  (`src/adf/README.md`); load order, load type, and target objects are
  data, not code.
- **Secure by default** — managed identities and RBAC are the default
  path, not an opt-in hardening pass; see `security-architecture.md` for
  the one deliberate exception (SQL authentication) and why it exists.
- **Infrastructure as Code** — every resource this repo provisions is
  defined in Bicep and Terraform, never created by hand through the
  portal; see `deployment-architecture.md`.
- **CI-validated** — every category of artifact (Bicep, Terraform, JSON,
  Python, SQL) has an automated check in `.github/workflows/ci.yml`, not
  just a manual review step.
- **Cloud-native** — built against Azure PaaS services (Data Factory,
  Databricks, Azure SQL, ADLS Gen2) rather than IaaS VMs running
  self-managed software.
- **Honest about verification status** — every module states plainly
  whether it's been run against something real or only offline-validated;
  see `docs/faq.md`'s "is this production-ready?" answer and
  `CHANGELOG.md`'s Verified/Added distinction. This is a principle, not an
  afterthought: a reader should never have to guess whether "done" means
  "tested" here.

## Core components

| Component | Role |
|---|---|
| Azure Data Factory | Metadata-driven orchestration and ingestion (`src/adf/`) |
| Azure Data Lake Storage Gen2 | Raw landing zone + Structured Streaming checkpoints |
| Azure Databricks / Delta Lake | Lakehouse medallion implementation (`src/databricks/`) |
| Azure SQL Database | T-SQL star schema implementation (`src/sql/`) |
| Microsoft Fabric / Azure Synapse | Adaptations of the SQL and Databricks patterns to two more Microsoft compute surfaces (`src/fabric/`, `src/synapse/`) |
| Azure Key Vault | Secret storage, RBAC-authorized, never access-policy-authorized |
| Azure Monitor / Log Analytics | Diagnostic settings, alerts (`src/monitoring/`) |
| Microsoft Entra ID | Managed identities, RBAC role assignments, OIDC for CI/CD (`src/security/`) |
| Bicep / Terraform | Infrastructure as Code, kept functionally identical between the two (`src/infrastructure/`) |
| GitHub Actions | CI validation across every artifact category (`.github/workflows/ci.yml`) |

## How to read the rest of this folder

1. `medallion-architecture.md` — the Bronze/Silver/Gold pattern, in both
   the SQL and Databricks engines, and exactly where they diverge.
2. `deployment-architecture.md` — what gets provisioned, in what order,
   and the resource topology.
3. `security-architecture.md` — the identity and RBAC model end to end.

For a narrower, task-oriented entry point (rather than this design-level
one), see `docs/architecture.md` and `docs/getting-started.md`.
