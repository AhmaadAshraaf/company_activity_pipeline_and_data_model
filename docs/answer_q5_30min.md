# Answer — Question 5 (30-minute cutover plan)

**If I have 30 minutes before tomorrow’s run I will implement a minimal, safe, end-to-end slice and defer higher-risk work.**

## Priority actions (what I will actually implement)
1. **Ingest CRM CSV → staging → dim**  
   - Copy the CRM file for *yesterday* into `stg.crm_companies` (ADF copy or one-off script).  
   - Run the CRM MERGE to upsert `dim.companies`.  
   - Rationale: deterministic source, quick to validate, provides company metadata needed downstream.

2. **Ingest a single day of product usage**  
   - Use `fetch_product_usage.py` in mock mode or with the API for `yesterday` to produce NDJSON.  
   - Copy the NDJSON into `stg.product_usage` via ADF or the helper loader.  
   - Rationale: validates the raw→staging→analytics path while avoiding pagination/backfill complexity.

3. **Merge analytics for the date**  
   - Run the analytics MERGE for `@load_date = yesterday` and the derived-metric update scoped to that date.  
   - Rationale: idempotent, bounded operations that produce dashboard-ready rows.

4. **Smoke checks & rollback readiness**  
   - Run quick checks: row counts, top-N active users, and null/consistency checks.  
   - If issues, run: `DELETE FROM analytics.company_activity_daily WHERE activity_date = '<date>';` then fix staging and re-run.

## What I explicitly postpone (and why)
- **Full API pagination & heavy backfill** — added complexity, rate limits, and long run time; do in controlled window.  
- **Large historical recompute and indexing** — could be resource-heavy and risk locks; schedule after validating daily runs.  
- **Advanced alerting runbooks & automation** — useful but non-critical for a single safe run.

## rationale for my choice
Deliver a correct, idempotent snapshot for one date that stakeholders can validate quickly. This minimizes risk while providing immediate business value and a clear path for extending to full production runs.
