```markdown
# Rollback & Retry

If a daily run produced incorrect data for a specific date, follow these steps to rollback and retry safely.

1. Identify the problematic date (example: `2025-11-23`) and confirm:
```sql
SELECT COUNT(*) FROM analytics.company_activity_daily WHERE activity_date = '2025-11-23';
```

2. Delete the analytics rows for that date:
```sql
DELETE FROM analytics.company_activity_daily WHERE activity_date = '2025-11-23';
```

3. (Optional) Clean staging for that date if the source was bad:
```sql
DELETE FROM stg.product_usage WHERE date = '2025-11-23';
-- and/or
DELETE FROM stg.crm_companies WHERE file_date = '2025-11-23';
```

4. Fix the source (upload corrected CRM CSV to raw/crm/ or regenerate NDJSON), then re-run:

- re-run the ingestion step (fetch script or re-upload to blob)

- re-run ADF copy to staging or run scripts/load_samples_to_sql.py

5. re-run sql/populate_analytics.sql for that load_date

Validate again:
```sql
SELECT * FROM analytics.company_activity_daily WHERE activity_date = '2025-11-23';
```

Important:

- MERGE operations are idempotent; re-running after deleting the date gives a clean state.

- Keep a copy of the problematic raw files (in blob or local) for post-mortem.

