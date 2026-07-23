# Healthcare — Architecture

Example-specific architecture notes. For the framework-wide patterns this
builds on (medallion layers, deployment topology, security model), see
`architecture/` at the repo root — this document only covers what's
specific to the healthcare accelerator.

## Star schema

```text
                    dim.dim_location  (generic, shared with banking/retail)
                          ▲
                          │ location_key
                    dim.dim_patient  (SCD2 — new)
                          ▲
              ┌───────────┴───────────┐
              │                       │
    fact.fact_claims  (new)   fact.fact_pharmacy  (new)
              │                       │
              └───────────┬───────────┘
                          │ provider_key
                    dim.dim_provider  (SCD2 — new, no location FK)

dim.dim_date (generic) FKs into both facts via date_key, not shown above.
```

Everything in this diagram except `dim.dim_location` and `dim.dim_date`
is new — see `README.md`'s "schema gap" section for why. `dim_patient`
and `dim_provider` are independent of each other (no FK between them);
both facts depend on both.

## Medallion flow

```text
raw/healthcare/{patients,providers,claims,pharmacy}/*.csv
        │
        ▼  (ADF pl_load_generic_full, metadata-driven — see adf/README.md)
staging.stg_healthcare_{patient,provider,claim,pharmacy}
        │
        ▼  (etl.usp_load_dim_patient_healthcare / _provider_healthcare /
        │   usp_load_fact_claims_healthcare / _pharmacy_healthcare)
dim.dim_patient, dim.dim_provider, fact.fact_claims, fact.fact_pharmacy

Databricks path, same source data, independent engine:
Bronze (Auto Loader) → Silver (generic conform) → Gold
  (dim_patient/dim_provider via generic SCD2 notebook;
   fact_claims/fact_pharmacy via bespoke notebooks — see
   databricks/README section of the main README)
```

The two engines (SQL, Databricks) implement the same dimensional model
independently — see `architecture/medallion-architecture.md` for why
that duplication is deliberate across the whole repo, not just here.

## Why patient and provider aren't dimensionalized further

`diagnosis_code`, `procedure_code`, `payer`, `drug_name`, `ndc_code`, and
`pharmacy_name` all stay as plain attributes on the fact tables rather
than becoming their own dimensions (`dim_diagnosis`, `dim_drug`, etc.).
A real healthcare warehouse likely would dimensionalize at least
diagnosis/procedure codes (they're standardized vocabularies — ICD-10,
CPT — with real hierarchy and lookup value). This accelerator doesn't,
on the same "don't dimensionalize without a concrete reason to" principle
`fact.fact_transactions` already applies to `transaction_type` — revisit
if a real reporting requirement needs code-level rollups or descriptions
attached.

## Grain

- `fact.fact_claims`: one row per claim (`claim_id`).
- `fact.fact_pharmacy`: one row per prescription fill (`prescription_id`).

Both are append-only, idempotent loads (anti-join on natural key),
same as every other fact in this repo — see
`docs/best-practices.md`'s "idempotency, everywhere" section.
