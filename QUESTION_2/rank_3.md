# Q2.1 — Rank #3 optimisation

**Change to make (one-file edit):**  
Add or ensure a **targeted index / partition strategy** on the raw events table and update the aggregation query to include a **date filter** that enables partition pruning. This can be done directly in the same SQL job file using an idempotent `CREATE INDEX IF NOT EXISTS` block plus a small query adjustment.

---

## Why this is #3
Indexing and partition pruning **reduce the cost of reading data**, but they cannot eliminate the fundamental inefficiency of full-history scans.  
This means:
- They **improve performance**, but **only** if the query already filters by date.
- They are helpful, but the gains are smaller than Rank #1 (incremental work) and Rank #2 (CTAS narrow table).

Therefore, indexing and pruning are ranked third:  
**important for long-term stability, but not the fastest win under a 30-minute one-file constraint.**

---

## What to add (T-SQL sketch — paste into the job file)

### 1. Create an index (idempotent)
A covering index on `(date, company_id, events)` helps the database skip irrelevant partitions and reduces random IO.

```sql
-- Create an index only if it doesn’t already exist
IF NOT EXISTS (
    SELECT 1 
    FROM sys.indexes 
    WHERE name = 'ix_stg_product_usage_date_company'
      AND object_id = OBJECT_ID('stg.product_usage')
)
BEGIN
    CREATE INDEX ix_stg_product_usage_date_company
        ON stg.product_usage(date, company_id)
        INCLUDE (events);
END;
```
- Add a date predicate to the aggregation to enable pruning
```sql
-- Example window (can use a fixed range or watermark logic from Rank #1)
DECLARE @start DATE = DATEADD(day, -7, CAST(GETDATE() AS DATE));
DECLARE @end   DATE = DATEADD(day, -1, CAST(GETDATE() AS DATE));

SELECT
    company_id,
    date,
    SUM(events) AS events
FROM stg.product_usage
WHERE date BETWEEN @start AND @end
GROUP BY company_id, date;
```
- Expected impact

1. Moderate speedup because the database can skip large chunks of data.

2. Lower IO cost as the query becomes more selective.

3. More stable query plans (fewer full scans, fewer spills).

> This optimisation is especially useful for very large tables where date-selective queries are frequent.

- Why it must be ranked #3 ?

1. It boosts performance, but does not change the fundamental amount of data scanned unless combined with incremental logic.

2. Only helpful when the query filters by date; otherwise, the index cannot be used.

3. Requires slight planning (index storage overhead, potential maintenance cost).

4. Still achievable safely in one file within 30 minutes.
