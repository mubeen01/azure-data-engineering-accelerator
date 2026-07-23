# Contributing

Thanks for your interest in ADEA. This document covers how the project is
structured and the conventions a change is expected to follow — start with
[docs/getting-started.md](docs/getting-started.md) if you haven't already,
it's the fastest orientation to the whole repo.

## Project structure

- `src/` — the generic, reusable framework (`sql/`, `adf/`, `databricks/`,
  `infrastructure/`, `monitoring/`, `security/`). Industry-agnostic by
  design; nothing here should reference a specific domain (banking,
  healthcare, etc.).
- `examples/` — end-to-end industry accelerators (currently just
  `banking/`) that consume the generic framework and extend it where an
  industry genuinely needs something the framework doesn't have (see
  `examples/banking/README.md`'s reconciliation section for what that
  looks like in practice — `dim_account`/`dim_loan` live there, not in
  `src/sql/`, because "account" isn't a universal concept).
- `tools/` — dev tooling that supports the project but isn't part of the
  deployed framework (currently `synthetic-data-generator/`).
- `architecture/` and `docs/` — design docs and orientation/troubleshooting.

See `ROADMAP.md` for what's built, what's in progress, and what's
explicitly out of scope for v1.0 (check there before assuming something's
missing by accident rather than by decision).

## Adding to the SQL framework

Read `src/sql/00-standards/naming-standards.md` and
`sql-coding-standards.md` first — naming conventions, SCD Type 1 vs. Type 2
patterns, idempotency requirements (every script must be safely
re-runnable), and the Synapse-compatibility rules (no `MERGE` in anything
that needs to run there, no filtered indexes) are all specified there, not
left to convention. A new generic dimension goes in `src/sql/03-dimensions/`;
a new industry-specific one goes in `examples/<industry>/sql/`.

## Adding an industry accelerator

`examples/banking/` is the reference pattern: real generated data (via
`tools/synthetic-data-generator/`), industry-specific SQL extensions where
needed, `etl.ctrl_pipeline_metadata` rows wiring it into the ADF
orchestrator, and Databricks notebooks/bundle where the generic ones don't
fit. Document any place your industry's real data shape doesn't match the
generic framework's assumptions — that reconciliation is the valuable part,
not something to hide. `examples/banking/README.md`'s mismatch table is
the template for how to write that up.

## Adding a domain to the synthetic data generator

See `tools/synthetic-data-generator/README.md`'s "Adding a domain" section
— one `generate(rows, seed) -> dict[str, DataFrame]` function registered
in `DOMAIN_GENERATORS`. Test it by actually running it without
`--output-dir` and checking the files land where you expect — an
off-by-one path bug shipped undetected in this repo once because the
smoke test always passed an explicit output path (see
`docs/troubleshooting.md`).

## Validating infrastructure changes

There's no CI enforcing this yet (`src/cicd/` is explicitly out of v1.0
scope — see `ROADMAP.md`), so it's on you before opening a PR:

- Bicep: `az bicep build --file main.bicep --stdout > /dev/null` should
  report zero errors.
- Terraform: `terraform init -backend=false && terraform validate` should
  pass (warnings are fine if you understand and can explain them — see
  `docs/troubleshooting.md` for one already-accepted example).
- SQL: there's no live CI database, but standing up SQL Server locally in
  Docker takes one command and is how this repo's own SQL layer was last
  verified — see `docs/getting-started.md`'s Path 2.

## Pull requests

1. Fork the repository.
2. Create a feature branch.
3. Make your changes, following the conventions above.
4. Validate what you can offline (see above).
5. Update the relevant module's README and `CHANGELOG.md` — every phase
   of this project has kept both current as part of the change itself,
   not as a follow-up.
6. Submit a PR describing what changed and why.

## Reporting issues

Include:

- What you were trying to do, and which module/phase it's in
- Environment (Azure region/SKU if relevant, local tool versions)
- Exact error message/output
- Steps to reproduce
- Expected behavior

Check `docs/troubleshooting.md` first — your issue might already be a
documented, known trade-off rather than a bug.
