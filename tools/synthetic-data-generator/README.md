# Synthetic Data Generator

Generates realistic sample data for ADEA's example domains instead of
committing large static CSVs. Row counts are configurable — generate 1,000
rows for a quick local test or 1,000,000 for a load-testing dataset by
changing `--rows`.

## Usage

```bash
pip install -r requirements.txt

python -m generator.cli --domain banking --rows 1000
python -m generator.cli --domain healthcare --rows 1000
python -m generator.cli --domain retail --rows 1000
```

Output defaults to `datasets/<domain>/` at the repo root (overridable with
`--output-dir`), matching the shape ADF (Phase 4) will later land into
`staging.*` tables (see `src/sql/06-stored-procedures/00_Create_Staging_Tables.sql`).

Pass `--seed` for reproducible output across runs.

## Status

| Domain | Status |
|---|---|
| Banking | ✅ implemented — customers, accounts, transactions, loans |
| Healthcare | ✅ implemented — patients, providers, claims, pharmacy |
| Retail | ✅ implemented — customers, products, inventory, orders |
| Insurance | ⏳ Milestone 3.2 |

## Adding a domain

Add `generator/domains/<name>.py` with a `generate(rows: int, seed: int | None) -> dict[str, pd.DataFrame]`
function (one dict entry per output table), then register it in
`DOMAIN_GENERATORS` in `generator/cli.py`. See `banking.py` for the pattern:
a primary entity count (`rows`) with related tables scaled off it via fixed
ratios, so foreign keys between generated tables stay valid.

## Known limitations

Generation is a straightforward per-row loop, not vectorized — very large
row counts (tens of millions) will take a while. Acceptable for a v1; revisit
if that becomes a real bottleneck.
