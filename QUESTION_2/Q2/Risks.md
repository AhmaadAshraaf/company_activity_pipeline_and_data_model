# Q2.2 — Risks or Flaws in the SQL Snippet & How to Fix Them

## 1. Full-table scan (no date filtering)
**Risk:**  
The query reads *every* row in `fact_events` every day. This grows linearly with table size and is the main reason jobs become slow or exceed SLAs.

**Fix:**  
Add a date predicate (or incremental logic). Example:
```sql
WHERE date BETWEEN @start AND @end
```
> Or implement a watermark-based incremental window.
---
## 2. No handling of duplicates or late-arriving events

**Risk:**
If the same event lands twice (common in event pipelines) or if events arrive late, SUM(events) will double-count or miss corrections. This creates dashboard mismatches.

**Fix 1** — Dedupe before grouping:
```sql
SELECT company_id, date, SUM(events)
FROM (
    SELECT DISTINCT event_id, company_id, date, events
    FROM stg.product_usage
) d
GROUP BY company_id, date;
```

**Fix 2** — Use MERGE into an aggregates table
(Store daily totals and update only changed dates.)
---
## 3. No data validation (NULLs, invalid dates, type drift)

**Risk:**
events may be NULL, negative, or non-numeric. date may include timezone differences. These inconsistencies propagate into analytics.

**Fix:**
Normalize before aggregation:
```sql
SELECT 
    company_id,
    CAST(date AS DATE) AS date,
    SUM(COALESCE(CAST(events AS BIGINT), 0)) AS events
FROM stg.product_usage
...
```
> Add sanity checks or constraints to catch invalid rows early.
