-- sql/populate_analytics.sql
-- Merge CRM into dim and merge daily analytics from staging, then compute derived metrics.

-- 1) Upsert dim.companies from today's CRM staging file
MERGE INTO dim.companies AS tgt
USING (
  SELECT company_id, name, country, industry_tag, last_contact_at
  FROM stg.crm_companies
  WHERE file_date = CAST(GETDATE() AS DATE)
) AS src
ON tgt.company_id = src.company_id
WHEN MATCHED THEN
  UPDATE SET name = src.name,
             country = src.country,
             industry_tag = src.industry_tag,
             last_contact_at = src.last_contact_at,
             updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
  INSERT (company_id, name, country, industry_tag, last_contact_at, created_at, updated_at)
  VALUES (src.company_id, src.name, src.country, src.industry_tag, src.last_contact_at, SYSUTCDATETIME(), SYSUTCDATETIME());

-- 2) Prepare load date (yesterday)
DECLARE @load_date DATE = CAST(GETDATE() - 1 AS DATE);

-- 3) Merge daily usage into analytics table
MERGE INTO analytics.company_activity_daily AS tgt
USING (
  SELECT
    u.company_id,
    @load_date AS activity_date,
    COALESCE(c.name, 'UNKNOWN') AS company_name,
    c.country,
    c.industry_tag,
    c.last_contact_at,
    COALESCE(u.active_users, 0) AS active_users,
    COALESCE(u.events, 0) AS events,
    SYSUTCDATETIME() AS src_ingested_at
  FROM (
    SELECT company_id, SUM(active_users) AS active_users, SUM(events) AS events
    FROM stg.product_usage
    WHERE date = @load_date
    GROUP BY company_id
  ) u
  LEFT JOIN dim.companies c ON c.company_id = u.company_id
) AS src
ON tgt.company_id = src.company_id AND tgt.activity_date = src.activity_date
WHEN MATCHED THEN
  UPDATE SET
    company_name = src.company_name,
    country = src.country,
    industry_tag = src.industry_tag,
    last_contact_at = src.last_contact_at,
    active_users = src.active_users,
    events = src.events,
    updated_at = SYSUTCDATETIME(),
    source = 'merged'
WHEN NOT MATCHED THEN
  INSERT (company_id, activity_date, company_name, country, industry_tag, last_contact_at, active_users, events, created_at, updated_at, source)
  VALUES (src.company_id, src.activity_date, src.company_name, src.country, src.industry_tag, src.last_contact_at, src.active_users, src.events, SYSUTCDATETIME(), SYSUTCDATETIME(), 'merged');

-- 4) Derived metrics: rolling windows + activity_consistency_30d
WITH metrics AS (
  SELECT
    company_id,
    activity_date,
    active_users,
    SUM(active_users) OVER (PARTITION BY company_id ORDER BY activity_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7d_active_users,
    SUM(events) OVER (PARTITION BY company_id ORDER BY activity_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS rolling_30d_events,
    AVG(active_users * 1.0) OVER (PARTITION BY company_id ORDER BY activity_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS avg_30d_active,
    STDEV(active_users * 1.0) OVER (PARTITION BY company_id ORDER BY activity_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS stddev_30d_active,
    LAG(active_users) OVER (PARTITION BY company_id ORDER BY activity_date) AS prev_active_users
  FROM analytics.company_activity_daily
  WHERE activity_date <= @load_date
)
UPDATE a
SET
  a.rolling_7d_active_users = m.rolling_7d_active_users,
  a.rolling_30d_events = m.rolling_30d_events,
  a.activity_consistency_30d = CASE WHEN m.avg_30d_active IS NULL OR m.avg_30d_active = 0 THEN NULL
                                   ELSE m.stddev_30d_active / m.avg_30d_active END,
  a.active_users_mom_pct = CASE WHEN m.prev_active_users IS NULL OR m.prev_active_users = 0 THEN NULL
                                ELSE (m.active_users - m.prev_active_users) * 1.0 / m.prev_active_users END,
  a.usage_density = CASE WHEN m.active_users = 0 THEN NULL ELSE a.events * 1.0 / NULLIF(m.active_users,0) END,
  a.is_churn_risk = CASE
     WHEN m.rolling_7d_active_users <= 3 AND DATEDIFF(day, a.last_contact_at, SYSUTCDATETIME()) > 30 THEN 1
     WHEN m.prev_active_users IS NOT NULL AND (m.active_users < 0.3 * m.prev_active_users) THEN 1
     ELSE 0
  END,
  a.updated_at = SYSUTCDATETIME()
FROM analytics.company_activity_daily a
JOIN metrics m ON a.company_id = m.company_id AND a.activity_date = m.activity_date
WHERE a.activity_date = @load_date;
