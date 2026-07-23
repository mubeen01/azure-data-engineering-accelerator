# Fabric Warehouse Compatibility

Microsoft Fabric's Data Warehouse is T-SQL, so `src/sql/` mostly ports —
but not entirely. This document is the compatibility table (same spirit
as the Synapse notes in `src/sql/00-standards/sql-coding-standards.md`)
rather than a duplicated copy of every script, since the two would drift
and the actual DDL is ~95% identical.

## The one change that affects every table: no `IDENTITY`

**Fabric Warehouse does not support `IDENTITY` columns at all.** Every
surrogate key in `src/sql/03-dimensions/` and `src/sql/04-facts/` is
declared `INT IDENTITY(1,1)` — none of that DDL runs unmodified on
Fabric. The standard workaround:

```sql
-- Instead of:
customer_key INT IDENTITY(1,1) NOT NULL,

-- Use a NEXT VALUE FOR a sequence, or compute the next key explicitly:
CREATE SEQUENCE dim.seq_customer_key AS INT START WITH 1 INCREMENT BY 1;
-- ...
customer_key INT NOT NULL DEFAULT (NEXT VALUE FOR dim.seq_customer_key),
```

`CREATE SEQUENCE` **is** supported on Fabric Warehouse, which is why
that's the recommended replacement rather than a `MAX(key) + 1` pattern
(which has an obvious race condition under concurrent loads that a
sequence doesn't).

## Other divergences

| Feature | Azure SQL DB / SQL Server | Synapse dedicated pool | Fabric Warehouse |
|---|---|---|---|
| `IDENTITY` | ✅ | ✅ | ❌ — use `SEQUENCE` instead (above) |
| `MERGE` | ✅ | ❌ | ✅ (supported, unlike Synapse dedicated pools) |
| Explicit clustered columnstore index (`CREATE CLUSTERED COLUMNSTORE INDEX`) | N/A | ✅ manual | ❌ — storage is fully managed; there's no equivalent DDL, `src/sql/08-indexes/01_Create_Fact_Columnstore_Indexes.sql` has nothing to port to |
| Filtered indexes | ✅ | ❌ | ❌ — same as Synapse, enforce the SCD Type 2 `is_current` invariant in the load procedure |
| Enforced `PRIMARY KEY`/`FOREIGN KEY`/`UNIQUE` | ✅ | ⚠️ `NOT ENFORCED` | ⚠️ `NOT ENFORCED` — same informational-only behavior as Synapse |
| Cross-database queries | ❌ (Azure SQL DB) / ✅ (SQL Server) | ❌ | ✅ — Fabric Warehouse can query across a workspace's items, including Lakehouses, which none of the other three targets can do |

## What this means for the load procedures

`src/sql/06-stored-procedures/*.sql` use `MERGE` for SCD Type 1 loaders
and plain `INSERT`/`UPDATE` for SCD Type 2 (chosen specifically for
Synapse portability — see the header comments in those files). Both
patterns work unmodified on Fabric Warehouse, since Fabric supports
`MERGE`. The only required change to port a loader is the `IDENTITY` →
`SEQUENCE` swap on the target table's DDL — the procedures themselves
don't reference `IDENTITY` directly (they rely on the engine assigning
the key), so once the table DDL uses a sequence default instead, the
existing `INSERT` statements (which never list the surrogate key column)
work as-is.

## Not built here

A full parallel copy of every `src/sql/` script rewritten for Fabric
Warehouse — the delta is small and mechanical (this document) rather than
substantial enough to justify a duplicate tree that would need to stay in
sync forever. If Fabric Warehouse becomes a real deployment target for
this project, generating that parallel tree from these rules would be
the next step, not a rewrite from scratch.
