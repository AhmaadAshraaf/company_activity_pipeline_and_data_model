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


---


---

### C — `run_once.sh` (simple wrapper for demo runs)

Create `run_once.sh` at repo root (make it executable). This is a simple script to run the mock demo. Adjust if you want to call real services later.

```bash
#!/usr/bin/env bash
# run_once.sh - demo wrapper (mock mode)
# Usage: ./run_once.sh 2025-11-23

set -e

DATE=${1:-2025-11-23}

echo "1) activating venv and installing requirements (if needed)"
# Uncomment if you want an automatic venv creation during demo
# python -m venv .venv
# source .venv/bin/activate
# pip install -r requirements.txt

echo "2) running fetch_product_usage.py in mock mode for date $DATE"
python scripts/fetch_product_usage.py --start "$DATE" --end "$DATE" --mock

echo "3) writing output files to samples_output/ (see files)"
ls -lah samples_output || true

echo "Done. Next: load samples to SQL (optional) and run SQL scripts."
echo "To load to SQL (if configured): python scripts/load_samples_to_sql.py --path samples_output"
echo "Then run the DDL and populate scripts in your SQL client."
```

Make it executable locally:
```bash
chmod +x run_once.sh
```
