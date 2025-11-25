# Q2.1 — Rank #2 optimisation

**Change to make (one-file edit):**  
Add a **materialization / CTAS (Create Table As Select)** step that narrows and pre-structures the raw events for the date window being processed, then run the `GROUP BY` against this much smaller, partition-friendly table. Insert the CTAS + subsequent aggregation into the same SQL job file you can edit in 30 minutes.

---

## Why this is #2
- **High impact when raw table is wide or contains heavy payloads (JSON):** CTAS reduces IO by projecting only the required columns and applying initial normalization (casts, timezone -> DATE), which makes the heavy `GROUP BY` much faster.  
- **Safe & reversible:** You create a temp/short-lived table for the window being processed (idempotent create/drop), so it has low blast radius.  
- **One-file edit:** You can add CTAS creation and use it immediately in the same job file without changing other pipeline components.

> CTAS is the second-best optimisation because it delivers strong performance gains **only after** you control the size of the data being processed. Its main benefit comes from reducing I/O by stripping wide payloads (e.g., JSON or unnecessary columns) into a smaller, partition-friendly table before aggregation. This makes the GROUP BY step much faster, but it still depends on how much data we scan.
In contrast, Rank #1 removes unnecessary full-history scans entirely — that’s a deeper, more systemic win. CTAS then becomes the next logical enhancement: once the job is incremental, CTAS makes the remaining per-day or per-window processing even more efficient without touching other parts of the pipeline.

---

## What to add (T-SQL sketch — paste into the job file)

1. **Define the window** (reuse watermark approach or accept a manual `@start/@end` for testing):

```sql
-- example window (adapt if using watermark)
DECLARE @start DATE = DATEADD(day, -7, CAST(GETDATE() AS DATE));  -- last 7 days example
DECLARE @end   DATE = DATEADD(day, -1, CAST(GETDATE() AS DATE));  -- up to yesterday
```
- Create a narrow, partition-friendly temp table (idempotent CTAS):
```sql
-- create schema if not exists
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')
  EXEC('CREATE SCHEMA stg');

-- drop temp table if exists (safe for re-run)
IF OBJECT_ID('stg.events_narrow', 'U') IS NOT NULL
  DROP TABLE stg.events_narrow;

-- CTAS: select only the columns we need, canonicalize date and types
SELECT
  CAST(company_id AS BIGINT)      AS company_id,
  CAST(CAST(date AS DATE) AS DATE) AS date,
  COALESCE(CAST(events AS BIGINT), 0) AS events
INTO stg.events_narrow
FROM stg.product_usage
WHERE date BETWEEN @start AND @end;
```
- Run the aggregation against the narrow table and MERGE into aggregates
```sql
WITH daily AS (
  SELECT company_id, date, SUM(events) AS events
  FROM stg.events_narrow
  GROUP BY company_id, date
)
MERGE INTO agg.daily_company_events AS tgt
USING daily AS src
  ON tgt.company_id = src.company_id AND tgt.date = src.date
WHEN MATCHED THEN
  UPDATE SET events = src.events, updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
  INSERT (company_id, date, events, created_at, updated_at)
  VALUES (src.company_id, src.date, src.events, SYSUTCDATETIME(), SYSUTCDATETIME());
```
