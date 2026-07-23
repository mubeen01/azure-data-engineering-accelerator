# FAQ

Answers grounded in the current state of the repo (see `ROADMAP.md` for
the authoritative, always-current version of "what's actually done").

## Is this production-ready?

No, not yet, and the repo doesn't claim otherwise. Every SQL/Bicep/
Terraform/ADF/Databricks/Fabric/Synapse artifact is written and validated
to the ceiling this project's environment allows — offline compilers
(`az bicep build`, `terraform validate`), JSON/Python syntax checks, and
one live SQL Server 2022 container run covering database/schema/dimension
creation. **None of it has been deployed against a real Azure
subscription, Databricks workspace, Fabric tenant, or Synapse workspace
yet.** Treat this as a well-reasoned, internally consistent starting
point to adapt, not a drop-in production system. `CHANGELOG.md`'s
"Verified" vs "Added" sections are the precise record of what's actually
been run versus just written.

## Do I need an Azure subscription to try this?

No, for two of the four paths in `docs/getting-started.md`: generating
synthetic data (Python only) and standing up the SQL warehouse locally in
a Docker SQL Server container. You only need Azure for deploying the
infrastructure (Path 4) or running the Databricks notebooks against a
real workspace. See `docs/installation.md` for exactly which tools each
path needs.

## Which industries are supported?

Banking, Healthcare, and Retail are all fully wired end-to-end examples
today (`examples/{banking,healthcare,retail}/`) — real generated data,
SQL warehouse extensions (or, for retail, reused generic tables), ADF
metadata rows, and a Databricks bundle job each. They hit different
flavors of "the generic framework doesn't just work as-is": healthcare
needed 4 entirely new tables (nothing generic maps onto patient/provider
at all), while retail reused 3 of its 4 target tables unmodified but
still needed its own load procedures. Worth reading `examples/*/README.md`'s
"reconciliation gap" / "schema gap" sections together if you want the
full picture. Insurance has neither a generator nor an accelerator yet —
it doesn't even have a defined dataset shape, unlike the other three,
which each had at least an empty placeholder CSV to design against.
`.github/GOOD_FIRST_ISSUES.md`'s "Add the Insurance domain to the
synthetic data generator" is the concrete next step.

## Fabric, Synapse, or Databricks — which should I use?

They're not mutually exclusive alternatives so much as adaptations of the
same two-engine model (`docs/architecture.md`) to different compute
surfaces:
- **Databricks** (`src/databricks/`) — the primary, most-built-out
  lakehouse path (Auto Loader, streaming, full SCD1/SCD2 tooling).
- **Fabric** (`src/fabric/`) — Lakehouse notebooks adapted from the
  Databricks path (no Auto Loader, since `cloudFiles` is
  Databricks-proprietary) plus Fabric Warehouse as a SQL-framework port.
- **Synapse** (`src/synapse/`) — serverless SQL querying Gold Delta tables
  directly via `OPENROWSET ... FORMAT = 'DELTA'` (no data movement), plus
  Spark pool notebooks adapted from the Databricks path.

Pick based on what compute your organization already has, not a
capability gap — the underlying dimensional model is identical across all
three.

## Why two IaC implementations (Bicep and Terraform) instead of one?

So teams that have already standardized on one don't have to translate the
other. Both provision the same resources with the same names and the same
auth model, kept deliberately in sync (`docs/best-practices.md`'s "keep
Bicep and Terraform functionally identical" section) — pick whichever your
organization already uses, not both.

## Why does the SQL linked service use a password instead of Managed
Identity, when everything else uses Managed Identity?

Wiring Azure AD-only authentication through an ADF linked service needs
additional AAD admin configuration on the SQL server that's a bigger lift
than this accelerator's scope — a deliberate tradeoff, not an oversight.
`src/security/` adds an Entra ID admin on the SQL server as a second,
additive, human-facing auth path; a team that wants to drop SQL auth
entirely can build on that. See `architecture/security-architecture.md`.

## What happens if I run the generator with a huge `--rows` value?

Nothing structurally different — `--rows` (e.g. customer count for
banking) drives the same code path whether you pass 1,000 or 1,000,000;
that was a deliberate Phase 3 design goal so generated data doesn't need
committing as static CSVs. Memory/runtime scale roughly linearly with row
count since it's all in-process pandas — there's no batching for
extremely large runs.

## How do I add a new industry accelerator?

Banking, Healthcare, and Retail are already done — see
`examples/{banking,healthcare,retail}/README.md`. For Insurance, the
generator has to come first: write
`tools/synthetic-data-generator/generator/domains/insurance.py`,
register it in `cli.py`'s `DOMAIN_GENERATORS`, following the
`generate(rows, seed) -> dict[str, DataFrame]` pattern — that domain has
no dataset shape defined yet, so it needs schema design before generation
can even start (unlike healthcare/retail, which had at least an empty
placeholder CSV shape to design against). Once the data exists, follow
any of the three existing accelerators as a template: `sql/` (schema
extensions or reused generic tables — see `examples/retail/README.md`
for why those are two different questions), `adf/README.md` (metadata
seed rows, no pipeline JSON needed — ADF is metadata-driven), `databricks/`
(a bundle + bespoke Gold fact notebooks), `README.md`, and
`architecture.md`. `docs/best-practices.md`'s "extend the generic
framework, don't fork it" section is the guiding principle throughout.

## Is there CI?

Yes — `.github/workflows/ci.yml`, added recently: five jobs validating
Bicep, Terraform, JSON (every ADF/Fabric/Synapse pipeline file), Python
syntax (every notebook, plus a live smoke-test run of the generator), and
SQL (every script in `src/sql/` and `examples/banking/sql/` against a real
SQL Server 2022 service container). It has not yet been observed running
on GitHub's actual infrastructure — first real run happens on push.

## How do I report a bug or request a feature?

`.github/ISSUE_TEMPLATE/` has templates for bug reports, feature requests,
and documentation issues. See `CONTRIBUTING.md` for the full contribution
workflow and `.github/GOOD_FIRST_ISSUES.md` for concrete, already-scoped
starting points.

## What license is this under?

MIT — see `LICENSE`.
