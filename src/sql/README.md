# SQL Framework

The SQL Framework provides enterprise-ready SQL Server and Azure SQL scripts for building modern data warehouses.

## Objectives

- Production-ready database design
- Star schema implementation
- Performance optimization
- Data validation
- Reusable stored procedures
- Enterprise naming standards

---

## Folder Structure

00-standards

Naming and coding standards

01-database

Database creation scripts

02-schemas

Business schemas

03-dimensions

Dimension tables

04-facts

Fact tables

05-views

Reporting views

06-stored-procedures

Reusable ETL procedures

07-functions

Utility functions

08-indexes

Performance optimization

09-seed-data

Deterministic reference/calendar seed data (e.g. dim_date) — not synthetic
business data, that's tools/synthetic-data-generator (Phase 3)

10-validation

Data quality validation

11-performance

Performance tuning

12-maintenance

Maintenance jobs

---

## Supported Database

- Azure SQL Database

- SQL Server

- Azure Synapse Dedicated SQL Pool

---

## Design Principles

- Star Schema

- Slowly Changing Dimensions

- Surrogate Keys

- Audit Columns

- Enterprise Naming Standards

- Metadata-driven ETL

- High Performance

---

## Status

✅ Complete (Phase 2, Milestones 2.1–2.5) — see [ROADMAP.md](../../ROADMAP.md)