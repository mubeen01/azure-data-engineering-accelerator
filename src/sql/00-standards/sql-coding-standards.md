# SQL Coding Standards

Applies to all scripts under `sql/`. Target dialect is T-SQL (Azure SQL Database /
SQL Server / Azure Synapse dedicated SQL pool) — see compatibility notes at the bottom
for where the three targets diverge.

## Idempotency

Every script must be safely re-runnable.

- Objects: guard with existence checks before create/drop.
  ```sql
  IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dim')
      EXEC('CREATE SCHEMA dim');
  ```
- Procedures/views/functions: use `CREATE OR ALTER` instead of `DROP` + `CREATE`.
- Seed/reference data: use `MERGE` or an existence check, never a bare `INSERT`.

## Formatting

- SQL keywords in `UPPERCASE` (`SELECT`, `FROM`, `WHERE`, `JOIN`).
- Identifiers in `snake_case`, always schema-qualified (`dim.dim_customer`, never
  bare `dim_customer`).
- One column per line once a statement has more than ~3 columns; comma-first or
  comma-last is fine as long as a single script is internally consistent.
- No `SELECT *` outside of ad-hoc validation queries — name columns explicitly,
  since dimension/fact shape changes should be visible in diffs.
- Every script starts with a header comment: purpose, and which milestone/folder it
  belongs to. Keep it to 2-3 lines — don't restate the filename.

## Procedures

- `SET NOCOUNT ON` at the top of every procedure.
- Wrap multi-statement writes in `BEGIN TRY / BEGIN CATCH` with a transaction;
  roll back on error and re-raise via `THROW`.
- Parameters prefixed `@p_` (`@p_customer_id`), local variables `@v_`.
- Every ETL procedure writes a start/end row to `audit.log_etl_run` (procedure name,
  start time, end time, row count, status, error message if any). This is the hook
  Milestone 2.4 (logging) and Phase 4 (ADF error handling/retry) build on.

## Data quality / validation

- Validation checks (Milestone 2.4/10-validation) are procedures, not ad-hoc
  queries, so they can be scheduled and logged the same way as loads.
- A failed validation writes to `audit.log_data_quality` rather than only raising
  an error, so failures are queryable after the fact.

## Performance

- Every `fact` table has a clustered columnstore index unless a specific query
  pattern justifies a rowstore clustered index instead — call out the reason in a
  comment when deviating.
- Foreign keys from `fact` to `dim` are indexed (the FK itself doesn't imply an
  index in SQL Server).
- No index or query hint (`NOLOCK`, `FORCESEEK`, etc.) without a comment explaining
  why the default behavior wasn't sufficient.

## Compatibility notes across targets

| Feature | Azure SQL DB | SQL Server | Synapse dedicated pool |
|---|---|---|---|
| `CREATE SCHEMA` | ✅ | ✅ | ✅ |
| Identity columns | ✅ | ✅ | ✅ (no `IDENTITY` gap guarantees under load — acceptable for surrogate keys) |
| Clustered columnstore index | ✅ | ✅ | ✅ (default table type — see script comments in `08-indexes`) |
| `MERGE` | ✅ | ✅ | ❌ not supported — use `INSERT`/`UPDATE` pair instead |
| Enforced `PRIMARY KEY`/`FOREIGN KEY`/`UNIQUE` | ✅ enforced | ✅ enforced | ⚠️ `NOT ENFORCED` only — informational for the optimizer, not validated on write |
| Filtered indexes (`CREATE INDEX ... WHERE`) | ✅ | ✅ | ❌ not supported — enforce the invariant in the load procedure instead |
| Cross-database queries | ❌ | ✅ | ❌ |

Scripts that can't run unmodified on all three targets say so in a header comment
rather than silently breaking on one platform.
