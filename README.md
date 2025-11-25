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
---
## Architecture diagram

<img width="3475" height="3176" alt="Untitled diagram-2025-11-25-105501" src="https://github.com/user-attachments/assets/c9538c58-e1b7-4000-9f8c-2d89beaa2d33" />

The diagram shows the daily Company Activity pipeline and the main components involved.

- **Key Vault** stores secrets (API keys, blob and DB credentials) and is referenced by ADF and the ingestion step.  
- **Blob Storage** holds raw inputs: the daily CRM CSV (`raw/crm/`) and NDJSON files produced by the product API (`product-api-raw/`), partitioned by date.  
- **Staging** tables (`stg.crm_companies`, `stg.product_usage`) are the landing zone for parsed raw data — they preserve provenance and raw payloads for audit and reprocessing.  
- **Dim / Analytics**: `dim.companies` is the canonical company master used for fast joins; `analytics.company_activity_daily` is the denormalized, one-row-per-company-per-day table with derived metrics for dashboards.  
- **ADF Pipeline** (`pl-company-activity-daily`) orchestrates the flow: verify CRM file → copy CRM to staging → trigger API ingestion → copy API raw to staging → run SQL merge + metric calculations → send success/failure notifications.

### Failure handling (short)
- **Local retries & idempotency:** Copy and merge steps are idempotent (MERGE by `company_id, activity_date`) so a safe re-run fixes transient issues without duplicating data.  
- **Retries:** Each ADF activity should have retry settings (e.g., 3 attempts with backoff) for transient network/API failures. The ingestion script (`fetch_product_usage.py`) implements simple retry/backoff for API calls.  
- **Centralized alerts:** All activity failure paths route to the same failure notification (`act-notify_failure`) which triggers a Logic App / webhook to post details to Teams/email, including pipeline name, failing activity, run id, and error message.  
- **Quick rollback:** If bad data lands in analytics for a date, a controlled rollback is `DELETE FROM analytics.company_activity_daily WHERE activity_date = '<date>'` followed by a re-run from staging. `docs/rollback.md` contains the exact steps.  
- **Observability:** Staging tables include provenance fields (`file_date`, `src_file_name`, `ingested_at`, `raw_json`) and a `data_quality_flag` in analytics to surface partial or low-confidence runs for human review.

Design goals: clear separation of raw vs canonical vs analytic layers, safe retries and idempotency for operations, centralized alerting, and an easy rollback path for operational safety.



---

## Files of interest
- `sql/create_tables.sql` — DDL for staging and analytics.
- `sql/populate_analytics.sql` — upsert + derived metrics.
- `scripts/fetch_product_usage.py` — ingestion script (reads env or Key Vault).
- `adf/diagram.mmd` — diagram for ADF flow.
- `samples/` — sample CRM CSV and product API JSON.

---
## Local demo and rollback

- For a quick local demo (no cloud keys), follow `docs/DEMO.md`. It shows how to run the ingestion in `--mock` mode and validate results.
- If you need to rollback a single day's analytics, use `docs/rollback.md`.
- For a scripted demo, use `./run_once.sh <date>` which runs the mock ingest and saves NDJSON to `samples_output/`.

