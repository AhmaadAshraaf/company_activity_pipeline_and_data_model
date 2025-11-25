# Company Activity Pipeline

**Short:** Company Activity pipeline — ETL design, SQL transformations, ADF orchestration diagram, and ingestion script for daily company activity analytics.

This repo contains:
- schema DDL and merge SQL (Azure SQL / Synapse T-SQL)
- Python ingestion script that writes NDJSON to Azure Blob (uses env or Key Vault)
- ADF architecture diagram
- A backup plan if I have only 30 minutes to get the pipeline ready for deployment
- sample input files for local/cloud demo

---
## Running the Pipeline (Overview)

Once the Azure environment is fully configured, the pipeline runs in a simple daily cycle. The CRM file is processed first to ensure company metadata is fresh, then the product-usage data is ingested, and finally all pieces are merged into the analytics table. The steps below outline the flow with brief details on what each stage accomplishes.

- **Load environment variables or Key Vault secrets**  
  Ensure the API URL, keys, and connection strings are available to both the ingestion script and SQL processes. This keeps configuration separate from code and avoids hard-coded credentials.

- **Upload the daily CRM CSV to `raw/crm/` and ingest it into `stg.crm_companies`**  
  This step brings in the latest company attributes (name, country, industry tag, last contact date) and acts as the foundation for the day’s analytics.

- **Merge CRM data into `dim.companies`**  
  Run the CRM MERGE block to refresh company metadata. This ensures any renamed or newly added companies appear correctly in downstream tables.

- **Run the product-usage ingestion script for the target date**  
  Executing  
  `python scripts/fetch_product_usage.py --start <date> --end <date>`  
  fetches the day’s product-usage activity and writes NDJSON files into the `product-api-raw` container, already partitioned by date.

- **Load NDJSON into `stg.product_usage`**  
  Using ADF or the helper loader script, copy the raw NDJSON files into the staging table. This keeps raw data and structured data clearly separated.

- **Execute the analytics merge script**  
  Running `sql/populate_analytics.sql` creates or updates the row for each company on that day. It also calculates rolling windows and derived metrics like engagement consistency, usage density, and churn-risk flags.

- **Validate output for the target date**  
  Run a quick SQL check to confirm row counts and look at a few sample rows. This makes sure the ingestion and merge steps behaved as expected.

- **Confirm the run and trigger standard notifications**  
  Once checks look correct, let ADF complete its success notification (email/Teams/webhook). The pipeline is then ready for the next cycle.
  
[<img width="2109" height="1672" alt="Untitled diagram-2025-11-24-233533" src="https://github.com/user-attachments/assets/34d9e302-5dd3-4467-b980-b576385e3556" />](https://github.com/AhmaadAshraaf/company_activity_pipeline_and_data_model/blob/main/adf/diagram.mmd)


---

## Files of interest
- `sql/create_tables.sql` — DDL for staging and analytics.
- `sql/populate_analytics.sql` — upsert + derived metrics.
- `scripts/fetch_product_usage.py` — ingestion script (reads env or Key Vault).
- `adf/diagram.mmd` — diagram for ADF flow.
- `samples/` — sample CRM CSV and product API JSON.
