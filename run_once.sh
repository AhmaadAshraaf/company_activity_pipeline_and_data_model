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
# Make it executable locally:

```bash
chmod +x run_once.sh
```
