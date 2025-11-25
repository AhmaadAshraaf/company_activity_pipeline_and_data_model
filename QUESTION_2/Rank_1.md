# Q2.1 — Rank #1 optimisation (30-minute, one-file change)

**Change to make (one-file edit):**  
Convert the full-table `GROUP BY` into an **incremental aggregation** that processes only new/unprocessed dates using a watermark, and `MERGE`s results into a persistent aggregates table (`agg.daily_company_events`). Implement this by updating the existing SQL job file that currently runs the full aggregation.

---

## Why this is #1
- **Biggest ROI with smallest blast radius:** Most long-running jobs re-scan unchanged history. Switching to incremental typically reduces runtime from hours to minutes because it avoids redundant work.  
- **Safe & idempotent:** `MERGE` + watermark yields repeatable runs and easy retries.  
- **One-file change:** All logic (watermark read, limited aggregation, MERGE, watermark advance) can be added to the existing job SQL in ~30 minutes.

---
# Minimal Prerequisites for Incremental Aggregation

Before the Rank #1 optimisation (incremental MERGE + watermark) can run, two lightweight supporting tables must exist:

- **`agg.daily_company_events`** — stores the incrementally built aggregates.  
- **`etl.watermark`** — stores the last processed date so we only process new data.

Both tables are **tiny**, **idempotent**, and can be safely created inside the same SQL job file using `IF NOT EXISTS` guards.  
You can paste the block below directly into the top of your aggregation SQL file.

---

## 1. `agg.daily_company_events` (aggregate store)

This table holds one row per `(company_id, date)` with the aggregated total number of events.  
It is intentionally small and index-friendly — ideal for fast daily merges.

```sql
-- Create schema if missing
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'agg')
    EXEC('CREATE SCHEMA agg');

-- Create daily aggregate table if missing
IF NOT EXISTS (
    SELECT * FROM sys.objects 
    WHERE name = 'daily_company_events' AND type = 'U' AND schema_id = SCHEMA_ID('agg')
)
BEGIN
    CREATE TABLE agg.daily_company_events (
        company_id     BIGINT      NOT NULL,
        date           DATE        NOT NULL,
        events         BIGINT      NOT NULL,
        created_at     DATETIME2   NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at     DATETIME2   NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_daily_company_events PRIMARY KEY (company_id, date)
    );
END;
```
## 2. etl.watermark (tracks last processed date)

- Tracks the last date successfully processed by the job.
- This enables the incremental window:

next_start_date = last_processed_date + 1

-- Create schema if missing
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'etl')
    EXEC('CREATE SCHEMA etl');

-- Create watermark table if missing
IF NOT EXISTS (
    SELECT * FROM sys.objects
    WHERE name = 'watermark' AND type = 'U' AND schema_id = SCHEMA_ID('etl')
)
BEGIN
    CREATE TABLE etl.watermark (
        job_name        VARCHAR(200) NOT NULL,
        processed_date  DATE         NOT NULL,
        created_at      DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_watermark PRIMARY KEY (job_name, processed_date)
    );
END;
---

## What to add (T-SQL sketch — paste into the job file)

```sql
-- 1) Get last processed date (watermark)
DECLARE @last_date DATE = (
  SELECT MAX(processed_date)
  FROM etl.watermark
  WHERE job_name = 'daily_company_events'
);

-- 2) Define processing window (next day after watermark up to yesterday)
DECLARE @start DATE = DATEADD(day, 1, ISNULL(@last_date, '2025-01-01'));
DECLARE @end DATE = DATEADD(day, -1, CAST(GETDATE() AS DATE));

IF @start <= @end
BEGIN
  -- 3) Aggregate only the new window
  WITH daily AS (
    SELECT company_id, CAST(date AS DATE) AS date, SUM(COALESCE(events,0)) AS events
    FROM stg.product_usage
    WHERE date BETWEEN @start AND @end
    GROUP BY company_id, CAST(date AS DATE)
  )
  -- 4) Idempotent upsert into a persistent aggregate table
  MERGE INTO agg.daily_company_events AS tgt
  USING daily AS src
    ON tgt.company_id = src.company_id AND tgt.date = src.date
  WHEN MATCHED THEN
    UPDATE SET events = src.events, updated_at = SYSUTCDATETIME()
  WHEN NOT MATCHED THEN
    INSERT (company_id, date, events, created_at, updated_at)
    VALUES (src.company_id, src.date, src.events, SYSUTCDATETIME(), SYSUTCDATETIME());

  -- 5) Advance watermark to mark processed range
  INSERT INTO etl.watermark(job_name, processed_date, created_at)
    VALUES ('daily_company_events', @end, SYSUTCDATETIME());
END
ELSE
BEGIN
  PRINT 'No new dates to process';
END
```
- Quick validation & rollback (what to run immediately after change)

- Smoke run: Run the job for a narrow window (set @start/@end manually to a single date) and confirm agg.daily_company_events contains expected rows.

- Reconcile sample rows: Compare raw totals vs aggregated for a few company_id/date pairs:

```sql
SELECT r.company_id, r.date, r.raw_events, a.events
FROM (
  SELECT company_id, date, SUM(events) AS raw_events
  FROM stg.product_usage
  WHERE date = '2025-11-23'
  GROUP BY company_id, date
) r
LEFT JOIN agg.daily_company_events a ON a.company_id = r.company_id AND a.date = r.date;
```
- Rollback (if needed):
```sql
DELETE FROM agg.daily_company_events WHERE date BETWEEN @start AND @end;
-- optionally remove watermark row(s) for that job/date
DELETE FROM etl.watermark WHERE job_name = 'daily_company_events' AND processed_date BETWEEN @start AND @end;
```
---
Expected impact

- Runtime: often reduces total job time by >80% after first full build (daily incremental runs only process new data).

- Cost: lower compute and IO costs due to smaller scans.

- Reliability: narrower window lowers chance of failures and simplifies troubleshooting.
---
