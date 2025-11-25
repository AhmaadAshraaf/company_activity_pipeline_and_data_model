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
## Files of Interest

This section gives a quick overview of the key files in the repository and the role each one plays in the pipeline.

### SQL Layer
- **sql/create_tables.sql**  
  Creates all pipeline tables: staging (`stg.*`), canonical dimension (`dim.companies`), and the analytics table (`analytics.company_activity_daily`).  
  This defines the data model and the relationships between raw, cleaned, and analytics-ready data.

- **sql/populate_analytics.sql**  
  Main transformation logic. Merges CRM + product-usage staging data, computes daily analytics rows, and calculates derived metrics (rolling windows, churn risk, consistency, etc.).  
  This script materializes the core dashboard dataset.

### Ingestion & Utility Scripts
- **scripts/fetch_product_usage.py**  
  Ingestion client for the product usage API. Fetches usage for a given date range, normalizes it, and writes NDJSON files to Blob storage (or locally in mock mode).  
  This is how product activity enters the pipeline.

- **scripts/load_samples_to_sql.py**  
  Optional utility for local development. Loads locally generated NDJSON files (mock mode outputs) into `stg.product_usage` without requiring Azure Data Factory.  
  Useful for demos and local testing without cloud credentials.

- **run_once.sh**  
  Small wrapper to run a full local mock demo (generate NDJSON → view outputs).  
  This helps quickly validate the pipeline behavior during development or showcase steps during a Loom walkthrough.

### ADF & Diagram
- **adf/diagram.mmd**  
  Mermaid diagram of the entire pipeline: CRM ingestion, API ingestion, staging loads, analytics merge, and failure notifications.  
  Shows orchestration and failure handling at a high level.

### Documentation
- **docs/company_activity_design.md**  
  Data model explanation, table grain, column rationales, and design reasoning for staging → dim → analytics layers.

- **docs/notes_components.md**  
  Additional notes on components, decisions, and architectural choices.

- **docs/DEMO.md**  
  Step-by-step guide for running a full local demo using mock API mode.  
  Allows running the pipeline without any real API keys or Azure services.

- **docs/rollback.md**  
  Short operational runbook showing how to safely rollback and re-run a single day’s analytics if there’s bad data.

- **docs/answer_q5_30min.md**  
  Concise answer for Question 5 (the 30-minute implementation plan) explaining prioritization, safe steps, and what to postpone.

### Samples & Outputs
- **samples/crm_sample.csv**  
  Example CRM file used for local testing or demos.

- **samples/product_api_sample.json**  
  Mock product-usage API response used for `--mock` ingestion mode.

- **samples_output/**  
  Folder where mock NDJSON is written during local demo runs (gitignored for cleanliness).

### Config & Meta
- **.env.template**  
  Template for required environment variables.  
  Reviewers can copy it to `.env` and plug credentials when available.

- **.gitignore**  
  Prevents committing secrets, virtual environments, temporary files, and NDJSON outputs.

- **requirements.txt**  
  Python dependencies for ingestion scripts and local testing.

- **README.md**  
  Overview, run instructions, and pointers to diagrams and documentation files.

---
## Local demo and rollback

- For a quick local demo (no cloud keys), follow `docs/DEMO.md`. It shows how to run the ingestion in `--mock` mode and validate results.
- If you need to rollback a single day's analytics, use `docs/rollback.md`.
- For a scripted demo, use `./run_once.sh <date>` which runs the mock ingest and saves NDJSON to `samples_output/`.

