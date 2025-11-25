# Local Demo (mock mode)

This page shows a minimal local demo to run the pipeline end-to-end without cloud credentials. It uses the included sample API payload and writes NDJSON to `samples_output/`.

Prerequisites:
- Python 3.9+ installed
- `requirements.txt` dependencies installed (see below)

Steps:

1. Create and activate a venv (optional but recommended)
```bash
python -m venv .venv
# macOS / Linux
source .venv/bin/activate
# Windows (PowerShell)
.\\.venv\\Scripts\\Activate.ps1
```
2. Install dependencies
```python
pip install -r requirements.txt
```

3. Run ingestion in mock mode (writes NDJSON to samples_output/)
```
python scripts/fetch_product_usage.py --start 2025-11-23 --end 2025-11-23 --mock
```

4. (Optional) Load NDJSON into a SQL instance referenced by SQL_CONN_STR:
```
# set SQL_CONN_STR in your environment or in .env (local testing)
python scripts/load_samples_to_sql.py --path samples_output
```

5. Run SQL DDL and merge:

- Execute sql/create_tables.sql in your SQL client.

- Execute sql/populate_analytics.sql (ensure @load_date is correct or adjust script).

6. Verify output:
```sql
SELECT * FROM analytics.company_activity_daily WHERE activity_date = '2025-11-23';
```

Notes:

- --mock uses samples/product_api_sample.json to emulate API responses.

- This demo does not require real API keys or Azure storage access.
