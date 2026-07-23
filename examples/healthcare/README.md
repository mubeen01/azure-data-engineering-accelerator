# Healthcare — Industry Accelerator

The second fully wired end-to-end example, built the same way
`examples/banking/` was: real generated data → SQL schema extensions →
ADF metadata-driven pipeline → Databricks medallion job. Where banking's
schema gap was two *new* dimensions layered onto an otherwise-reusable
generic model (`dim_account`, `dim_loan` both FK to the generic
`dim_customer`), healthcare's gap is bigger — nothing in the generic
model maps onto "patient" or "provider" at all, so this is a fully
independent star schema extension, following the same *conventions*
(SCD types, staging shape, audit logging, metadata-driven registration)
rather than reusing any generic table.

## Data

`datasets/healthcare/*.csv` are real output from
`tools/synthetic-data-generator` (`python -m generator.cli --domain
healthcare --rows 2000 --seed 42`) — 2,000 patients, 100 providers, 6,000
claims, 4,000 prescriptions. See
`tools/synthetic-data-generator/generator/domains/healthcare.py`.

## The schema gap: patient and provider have no generic equivalent

Unlike banking's `dim_account`/`dim_loan` (both FK to the generic
`dim.dim_customer`), healthcare's core entities don't extend anything
generic — a patient isn't a customer with extra fields, and a provider
isn't an employee:

- `sql/01_Create_Dim_Patient.sql` — SCD Type 2. `gender`, `date_of_birth`,
  `blood_type`, `insurance_plan` have no generic counterpart; FK to
  `dim.dim_location` (same reconciliation as customer/account, below).
- `sql/02_Create_Dim_Provider.sql` — SCD Type 2. Deliberately has **no**
  `dim.dim_location` FK — the generator's provider records carry only
  `city`/`region`, not a full postal address, so there's no real location
  entity to synthesize (see the file's own header comment).
- `sql/03_Create_Fact_Claims.sql`, `sql/04_Create_Fact_Pharmacy.sql` —
  both new facts. `diagnosis_code`/`procedure_code`/`payer`/`drug_name`
  etc. are kept as degenerate attributes on the fact rather than
  dimensionalized — no `dim_diagnosis` or `dim_drug` exists, same
  "don't dimensionalize without a real reason" judgment call
  `fact.fact_transactions` makes for `transaction_type`.

## The reconciliation gap: same pattern as banking, different entity

The generator embeds a patient's address directly on the patient record,
exactly like banking's customer records — no separate `location_id`:

| Mismatch | Generic framework assumed | Generator actually produces | Resolution |
|---|---|---|---|
| Patient address | a separate `location_id` FK | address embedded directly on the patient record | `sql/05_Load_Dim_Patient_Healthcare.sql` synthesizes `location_id = patient_id` and upserts `dim.dim_location` first, same pattern as `examples/banking/sql/03_Load_Dim_Customer_Banking.sql` |

This is the second time this exact mismatch has shown up (banking's
customer, now healthcare's patient) — good evidence it's a real,
recurring shape the generator produces, not a banking-specific one-off,
and that the "give the industry its own staging table + load procedure
that reconciles explicitly" pattern from `examples/banking/README.md`
generalizes rather than being special-cased.

## The load-order dependency

Both facts (`claim`, `pharmacy`) FK to *both* dimensions (`patient`,
`provider`) — `sql/09_Seed_Pipeline_Metadata_Healthcare.sql` sets
patient=10, provider=10 (independent of each other), claim=20,
pharmacy=20, so `pl_master_orchestrator`'s `load_priority` ordering (the
same mechanism banking's README documents surfacing as a real bug) loads
both dimensions before either fact. See `adf/README.md`.

## Databricks

`databricks/databricks.yml` wires a 10-task job: Bronze (4 entities) →
Silver (4 entities) → Gold dimensions (`dim_patient`, `dim_provider` —
via the generic SCD Type 2 notebook) → Gold facts
(`gold_load_fact_claims_healthcare.py`, `gold_load_fact_pharmacy_healthcare.py`
— bespoke, since the generic fact notebook is written for `fact_sales`
specifically). Unlike banking's `fact_transactions` notebook, which needs
a two-hop join through `dim_account` to reach `customer_key`, both
healthcare facts join directly to `dim_patient` and `dim_provider` —
single-hop, closer to the generic `fact_sales` notebook's shape.

Same deliberate simplification as banking: `dim_patient`'s address stays
a plain passthrough attribute on the Databricks side rather than being
resolved to a `location_key` — only the SQL path does that resolution.

## Validation status

- **Data generation**: ran for real, verified (2,000/100/6,000/4,000 rows,
  correct headers, referentially consistent — see
  `tools/synthetic-data-generator/README.md`).
- **SQL**: written and reviewed against the same patterns
  `examples/banking/sql/` already established; not executed against a
  live SQL Server/Azure SQL instance in this environment — same caveat as
  the rest of `src/sql/` and `examples/banking/sql/` before their later
  live-container verification pass (see `CHANGELOG.md`).
- **ADF**: no new pipeline JSON to validate (metadata-driven — see
  `adf/README.md`); the metadata seed script is plain T-SQL, covered by
  the SQL caveat above.
- **Databricks bundle**: YAML structurally reviewed (10 tasks, dependency
  graph checked by hand); notebook Python syntax-checked
  (`python3 -m py_compile`). `databricks bundle validate` needs a
  reachable workspace to fully pass — same caveat as
  `examples/banking/README.md`'s Databricks section.

## What's still not done

- Insurance accelerator — its generator doesn't exist yet either (Phase 3
  Milestone 3.2 is still open for that one domain).
- No employee/location dimensions beyond `dim_patient`'s resolved
  location — there's no "hospital branch" or "billing staff" concept in
  the generator's model.
- The actual ADF linked service source path / Databricks mount path
  (`/mnt/adea/raw/healthcare/...`) assumes the generated CSVs have been
  uploaded to the storage account's `raw` container — that upload step
  isn't automated here, same as banking.
- Retail's accelerator was built in the same pass as this one — see
  `examples/retail/README.md` for how differently that one's
  reconciliation story turned out (much of it reuses the generic
  framework unmodified, unlike healthcare's fully independent schema).
