# Getting Started

This is an orientation, not a duplicate of every module's own README —
each linked doc below is the actual source of truth for its folder. Start
here if you're new to the repo and want the shortest path to seeing the
whole thing work together, using the banking accelerator
(`examples/banking/`) as the concrete walkthrough.

## What's actually built (as of this writing)

See `ROADMAP.md` for the authoritative, current status of every phase.
Short version: the SQL framework, ADF framework, Databricks framework,
infrastructure (Bicep + Terraform), monitoring/security, and three
complete industry examples (banking, healthcare, retail) are all written.
What's *not* done yet: Insurance entirely (no generator, no dataset
shape, no accelerator), and nothing in this repo has been deployed
against a real Azure subscription — see `docs/troubleshooting.md`'s
verification-status notes before assuming something works end-to-end just
because it's written.

## Path 1: just want to see synthetic data

```bash
cd tools/synthetic-data-generator
pip install -r requirements.txt
python -m generator.cli --domain banking --rows 2000 --seed 42
python -m generator.cli --domain healthcare --rows 2000 --seed 42
python -m generator.cli --domain retail --rows 2000 --seed 42
```

Writes `datasets/<domain>/*.csv` — see
`tools/synthetic-data-generator/README.md` for each domain's tables.
Banking, healthcare, and retail are implemented; insurance isn't yet.

## Path 2: stand up the SQL warehouse locally (no Azure needed)

This is genuinely the fastest way to see the framework work, and it's how
Phase 8's SQL layer was actually verified (a real SQL Server 2022 Docker
container ran `01-database` through the dimension scripts with zero
errors — see the `[Unreleased]` section of `CHANGELOG.md`).

```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=<a-strong-password>" \
  -p 1433:1433 --name adea-sql -d mcr.microsoft.com/mssql/server:2022-latest
```

Then run, in order, against that instance (`sqlcmd` or any SQL client):

1. `src/sql/01-database/` → `src/sql/12-maintenance/` (numeric folder
   order — see `src/sql/README.md` for what each folder is)
2. `examples/banking/sql/` (numeric order — extends the generic framework
   with `dim_account`/`dim_loan`, and banking-shaped staging tables)
3. Load `datasets/banking/*.csv` into the `staging.stg_banking_*` tables
   (matching column names — no transformation needed, see
   `examples/banking/README.md`)
4. Run the load procedures in dependency order: `etl.usp_load_dim_customer_banking`
   → `etl.usp_load_dim_account` / `etl.usp_load_dim_loan` →
   `etl.usp_load_fact_transactions_banking` (the same order
   `etl.ctrl_pipeline_metadata.load_priority` encodes for ADF)

`docker rm -f adea-sql` when done.

Healthcare and Retail follow the exact same shape — swap step 2 for
`examples/healthcare/sql/` or `examples/retail/sql/`, step 3 for that
domain's `datasets/`, and step 4 for that example's own load procedures
(listed in its `README.md`). Retail is the interesting variant: its
dimension/fact *tables* are the generic ones from step 1, not new ones —
only its staging tables and load procedures are example-specific. See
`examples/retail/README.md`'s "reconciliation gap" section.

## Path 3: understand how the pieces connect

Read in this order:

1. `architecture/overview.md` — the high-level vision and principles.
2. `architecture/medallion-architecture.md` — Bronze/Silver/Gold, in both
   SQL and Databricks, and where they deliberately diverge.
3. `architecture/deployment-architecture.md` — what gets provisioned,
   in what order, and why `src/infrastructure/`, `src/monitoring/`, and
   `src/security/` are three separate deployments.
4. `architecture/security-architecture.md` — the identity/RBAC model
   end to end.
5. `examples/banking/README.md` — the first place every layer actually
   had to work together, including the real bugs that surfaced from doing
   so (an off-by-one path bug in the generator, a missing load-order
   guarantee in the ADF orchestrator) and how they were fixed.
   `examples/healthcare/README.md` and `examples/retail/README.md` are
   worth reading alongside it — each hit a different flavor of "the
   generic framework doesn't just work as-is."

## Path 4: deploy the infrastructure

`src/infrastructure/README.md` has the exact `az deployment` /
`terraform apply` commands for both Bicep and Terraform. Deploy that
first, then `src/monitoring/` and `src/security/` into the same resource
group — see `architecture/deployment-architecture.md` for why that order
matters and what depends on what.

## If something doesn't work

Check `docs/troubleshooting.md` first — it consolidates the gotchas this
repo's own development already ran into (RBAC prerequisites, Synapse
compatibility caveats, tooling quirks) rather than leaving them scattered
across a dozen module READMEs.

## Other reference docs

- `docs/installation.md` — exact tooling per path, if the commands above
  fail because something isn't installed yet.
- `docs/architecture.md` — a map of how every layer connects, before
  diving into `architecture/`'s detailed design docs.
- `docs/best-practices.md`, `docs/coding-standards.md`,
  `docs/naming-conventions.md` — read these before extending the
  framework (a new industry accelerator, a new module) so it stays
  consistent with what's already here.
- `docs/faq.md` — quick answers to the questions this repo gets asked
  most (production-readiness, which engine to pick, why SQL auth exists
  at all).
