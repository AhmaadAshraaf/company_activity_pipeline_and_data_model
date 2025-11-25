# Q2.4 — Slack-style update to Analytics Team

Hey team — quick update on the daily job and next steps to fix runtime + mismatch issues:

- **What I’ll change:** convert the full-table aggregation to an **incremental MERGE** (watermark-driven) into an `agg.daily_company_events` table and add a short reconciliation step that compares raw totals (staging) vs aggregates for each `company_id`/`date`. This reduces reprocessing and makes results idempotent.

- **Temporary caveats / short window work:** I will run a **small backfill** (1–7 days) to align historical totals — expect minor, temporary diffs on a few dates while we reconcile late-arriving or corrected events. After the backfill, daily runs will only process new dates.

- **What to watch for:** please flag any **large (>10%) deltas** between the dashboard and API for specific `company_id` + `date` pairs. If you see a spike/drop that looks wrong, include the company_id, date, and a screenshot — I’ll investigate duplicates/late-arrivals or normalization issues first.

- **Post-change visibility:** I’ll add a lightweight daily alert (Slack) when reconciliation delta for any company/date exceeds the threshold, and share a short runbook for how to request a re-run for a specific date.
