- `populate_analytics.sql` — core transformation: MERGE dim + MERGE analytics + compute derived metrics (answers Question 2 and implements the target table in Question 1).

- `fetch_product_usage.py` — API ingestion client: pages API, writes NDJSON to Blob (answers Question 4, used by Question 3 ADF flow).

- `load_samples_to_sql.py` — optional helper for local testing only; not needed when ADF Copy is used in production.

- `ls_keyvault` — must be used by linked services in production; diagram omits explicit arrows for readability—connect it in deployment.

- `product_api_sample.json` — local mock for safe testing and demos.

- `requirements.txt` — dependencies for local/dev runs.
