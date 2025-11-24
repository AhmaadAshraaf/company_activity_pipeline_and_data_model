# Company Activity — design summary

**Grain:** one row per `company_id` per `activity_date` (daily)

## Key table: `analytics.company_activity_daily`
Columns:
- `company_id` (VARCHAR) — join key; PK part 1
- `activity_date` (DATE) — PK part 2; partition column
- `company_name` (VARCHAR) — human label for reports
- `country` (VARCHAR) — geo segmentation, filters
- `industry_tag` (VARCHAR) — cohorting and analysis
- `last_contact_at` (DATETIME) — CRM last-touch; used for churn logic
- `active_users` (INT) — daily DAU signal from product API
- `events` (INT) — daily event count, volume signal
- `engagement_score` (FLOAT) — derived weighted score for quick ranking
- `activity_consistency_30d` (FLOAT) — derived: stddev/mean of active_users over 30d; flags volatility
- `rolling_7d_active_users` (INT) — 7-day smoothing
- `rolling_30d_events` (INT) — 30-day volume for quota/billing
- `active_users_mom_pct` (FLOAT) — day-over-day change
- `usage_density` (FLOAT) — events per active user; finds power-users
- `is_churn_risk` (BIT) — boolean derived from rules
- `est_monthly_active_users` (INT) — optional MAU estimate
- `source` (VARCHAR) — e.g. 'crm_csv', 'product_api', 'merged'
- `data_quality_flag` (VARCHAR) — quick health status
- `created_at`, `updated_at` (DATETIME)

## Monitoring & data quality
- data_quality_flag set during staging and merge.
- pipeline failure alerts routed to Teams/email from ADF/Logic App.
