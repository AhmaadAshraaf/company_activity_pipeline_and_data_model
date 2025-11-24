# Company Activity Pipeline (demo)

**Short:** Company Activity pipeline — ETL design, SQL transformations, ADF orchestration diagram, and ingestion script for daily company activity analytics.

This repo contains:
- schema DDL and merge SQL (Azure SQL / Synapse T-SQL)
- Python ingestion script that writes NDJSON to Azure Blob (uses env or Key Vault)
- ADF architecture diagram (Mermaid) and run plan for a 30-minute demo
- sample input files for local/cloud demo

---

## Quick steps (Azure cloud demo)

1. Copy `.env.template` → `.env` and fill values (or add secrets into Azure Key Vault).
2. Create Azure resources:
   - Storage account + containers `raw/crm/` and `product-api-raw`.
   - Azure SQL database (or Synapse) and a user with DB privileges.
   - (Optional) Azure Key Vault for secrets.
3. Run SQL DDL on Azure SQL:
   - Run `sql/create_tables.sql` to create staging, dim and analytics tables.
4. Upload `samples/crm_sample.csv` to blob container `raw/crm/` OR use the helper to insert into `stg.crm_companies`.
5. Run ingestion script to write NDJSON to blob:
   - `python scripts/fetch_product_usage.py --start 2025-11-23 --end 2025-11-23`
   - (Script reads secrets from env or Key Vault.)
6. Use ADF or the helper `scripts/load_samples_to_sql.py` to copy NDJSON from blob into `stg.product_usage`.
7. Run `sql/populate_analytics.sql` (or call the stored proc) to merge and compute derived metrics.
8. Query `analytics.company_activity_daily` to verify.

---

## Files of interest
- `sql/create_tables.sql` — DDL for staging and analytics.
- `sql/populate_analytics.sql` — upsert + derived metrics.
- `scripts/fetch_product_usage.py` — ingestion script (reads env or Key Vault).
- `adf/diagram.mmd` — Mermaid diagram for ADF flow.
- `samples/` — sample CRM CSV and product API JSON.

---

## Notes
- Secrets: recommended to store API_KEY, BLOB_CONN_STR, SQL_CONN_STR in Key Vault and grant Managed Identity to ADF/Function.
- For demo without real API key, use `samples/product_api_sample.json` and the helper script to load to blob / staging.
