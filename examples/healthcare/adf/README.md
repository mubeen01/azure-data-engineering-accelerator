# Healthcare — ADF

There is no healthcare-specific pipeline JSON here, and that's by design,
not a gap. `src/adf/` is metadata-driven (see `src/adf/README.md`): one
generic pipeline pair (`pl_load_generic_full`, `pl_load_generic_incremental`)
plus `pl_master_orchestrator`, which reads active rows from
`etl.ctrl_pipeline_metadata` and runs each one — full or incremental,
whichever the row says — instead of a hand-built pipeline per source
object. Adding a new object means inserting a metadata row, not authoring
a new ADF resource.

Healthcare's actual "ADF contribution" is
[`../sql/09_Seed_Pipeline_Metadata_Healthcare.sql`](../sql/09_Seed_Pipeline_Metadata_Healthcare.sql) —
four rows, one per source object:

| `object_name` | `load_priority` | `load_procedure_name` |
|---|---|---|
| `healthcare_patient` | 10 | `etl.usp_load_dim_patient_healthcare` |
| `healthcare_provider` | 10 | `etl.usp_load_dim_provider_healthcare` |
| `healthcare_claim` | 20 | `etl.usp_load_fact_claims_healthcare` |
| `healthcare_pharmacy` | 20 | `etl.usp_load_fact_pharmacy_healthcare` |

`load_priority` enforces the real dependency here: both facts (`claim`,
`pharmacy`) FK to *both* dimensions (`patient`, `provider`), so both
dimensions must finish loading (priority 10) before either fact starts
(priority 20) — `pl_master_orchestrator`'s `ORDER BY load_priority ASC,
object_name ASC` on its Lookup query is what actually guarantees this
(see `examples/banking/README.md`'s "load-order gap" section for why that
`ORDER BY` exists at all — it was a real bug found wiring banking, fixed
before healthcare needed it).

Once `src/infrastructure/` is deployed and the generated CSVs
(`datasets/healthcare/*.csv`) are uploaded to the storage account's `raw`
container at `raw/healthcare/<object>/`, running `pl_master_orchestrator`
picks up these four rows automatically — no additional ADF authoring
required. That upload step itself isn't automated (same caveat
`architecture/deployment-architecture.md` documents for banking).
