<!--
Draft content for two manual GitHub setup steps: enabling Discussions and
creating a Project board. Delete or archive this file once both exist.
-->

# Project Board

Suggested columns (GitHub Projects, "Board" view):

| Column | Contents |
|---|---|
| **Backlog** | Everything in `.github/GOOD_FIRST_ISSUES.md` not yet picked up, plus `ROADMAP.md`'s "Out of v1.0 scope" items (Fabric, Synapse, CI/CD) as low-priority, far-future cards |
| **Ready** | Issues with enough detail to start immediately — most of `GOOD_FIRST_ISSUES.md` qualifies as-is |
| **In Progress** | Actively being worked (link the branch/PR) |
| **In Review** | Open PR, awaiting review/merge |
| **Done** | Merged |

Suggested initial cards for **Backlog**/**Ready**, pulled directly from
`.github/GOOD_FIRST_ISSUES.md` (create the GitHub Issues first, then add
them as cards so the board and issue tracker stay linked):

1. Add Healthcare domain to the synthetic data generator
2. Add Retail domain to the synthetic data generator
3. Add Insurance domain to the synthetic data generator
4. Build a second industry accelerator end-to-end (depends on #2)
5. Add a worked Databricks Gold notebook for `fact_orders`
6. Wire Unity Catalog's storage credential (needs a live metastore)
7. Add a security-specific Key Vault audit alert
8. Automate the dataset-to-storage-account upload step
9. Add a "prod" Bicep parameters file
10. Verify SQL facts/procedures/banking extensions against a live SQL Server

# Discussions

Suggested categories to enable: **Announcements** (maintainer-only),
**General**, **Ideas**, **Q&A**, **Show and tell**.

## Welcome post draft (pin to Announcements)

---

**Welcome to Azure Data Engineering Accelerator**

ADEA is a reusable framework for building Azure data platforms — a full
SQL star schema, metadata-driven ADF pipelines, a Databricks medallion
implementation, Infrastructure as Code (Bicep + Terraform), and
monitoring/security, all designed to work together rather than as
disconnected samples.

**Where things stand at v1.0.0**: the core framework is built and one
complete industry accelerator (Banking) proves it works end-to-end — real
generated data flowing through SQL, ADF, and Databricks. Healthcare,
Retail, and Insurance are next, blocked only on their synthetic data
generators not existing yet (see `.github/GOOD_FIRST_ISSUES.md` if you
want to help close that gap).

**Verification status is documented, not hidden**: some of this has run
against real infrastructure (the SQL layer's core tables against a live
SQL Server; every Bicep/Terraform template offline-validates cleanly),
some hasn't yet (Databricks notebooks, a live Azure deployment). Check
`docs/troubleshooting.md` and `ROADMAP.md` before assuming something
works end-to-end just because it's written — and if you run something
that isn't listed as verified and it works (or doesn't), that's exactly
the kind of thing worth a post here.

Use **Q&A** for "how do I..." questions, **Ideas** for anything not
already tracked in `.github/GOOD_FIRST_ISSUES.md` or the project board,
and **Show and tell** if you build a new industry accelerator or extend
the framework — that's the whole point of this being reusable.

---
