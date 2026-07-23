# Performance Guidance

Applies to the dimensions/facts in `03-dimensions`/`04-facts`, loaded by the
procedures in `06-stored-procedures`.

## Columnstore rowgroup quality

Fact tables use a clustered columnstore index (`08-indexes`). Columnstore
compresses in batches of ~1,048,576 rows into a rowgroup; anything smaller
lands in an uncompressed "open" delta rowgroup until it fills or is merged.

- Load in batches of 100k+ rows where possible (`staging_batch_id` already
  groups a run's rows) rather than row-by-row inserts.
- Run `12-maintenance`'s columnstore rebuild job periodically so trickle
  inserts get compressed instead of accumulating as open rowgroups.

## Statistics

- After a large load (initial backfill, a big incremental batch), update
  statistics on the affected table — see `01_Update_Statistics.sql` in this
  folder.
- Don't disable auto-update statistics; the manual update is a supplement
  for right-after-a-big-load freshness, not a replacement.

## Query patterns

- Filter on `date_key` (an `INT`), not on a computed expression over
  `full_date` (`WHERE YEAR(full_date) = ...`) — the latter can't use the
  `ix_fact_*_date_key` indexes in `08-indexes`.
- Join fact to dimension on the surrogate `_key` columns, never the natural
  `_id` — that's the whole point of the surrogate key.
- Avoid `SELECT *` against fact tables; columnstore's per-column compression
  means unused columns aren't free to read, but a scan across all of them
  discards that benefit.

## Synapse dedicated SQL pool: distribution

This section is Synapse-specific — Azure SQL Database and SQL Server don't
have a distribution concept.

- Fact tables: `HASH` distribution on a high-cardinality, frequently-joined
  column (`customer_key` is a reasonable default) so joins to `dim_customer`
  don't require a data movement step.
- Small dimension tables (`dim_date`, `dim_currency`, `dim_source_system`):
  `REPLICATE` — a full copy on every compute node avoids shuffling them for
  every join.
- Larger, slowly-changing dimensions (`dim_customer`, `dim_product`,
  `dim_employee`): `HASH` distribution on the same key used for the fact
  table's distribution, or `ROUND_ROBIN` if no single join key dominates.
