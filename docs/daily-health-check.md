# Daily Health Check Runbook

Use this checklist to verify that all scheduled jobs ran successfully and the service is live. Run after **03:30 UTC** to give both jobs time to complete.

---

## Overview of scheduled jobs

| Job | Schedule (UTC) | What it does |
|-----|---------------|--------------|
| `doomsday-polymarket` | 01:00 | Fetches Polymarket data → lands in BigQuery |
| `weather-sync` | 03:00 | Exports BigQuery → GCS + GitHub |
| `weather-api` | always-on | REST API service; no schedule |

---

## Step 1 — Verify exported data is fresh (weather-sync output)

Check that `weather-sync` successfully pushed both data files to GCS and GitHub.

### 1a. GitHub

Open the data repo and confirm both files were updated today:

- [`data/snapshots.jsonl`](https://github.com/FG-PolyLabs/cloud-predict-analytics-data/commits/main/data/snapshots.jsonl)
- [`data/tracked_cities.jsonl`](https://github.com/FG-PolyLabs/cloud-predict-analytics-data/commits/main/data/tracked_cities.jsonl)

The most recent commit on each file should be dated **today**.

### 1b. GCS

Open the bucket and inspect the same two files:

```
https://console.cloud.google.com/storage/browser/fg-polylabs-weather-data?project=fg-polylabs
```

Check `Last modified` on:
- `data/snapshots.jsonl`
- `data/tracked_cities.jsonl`

Both should show **today's date**.

> **Tip:** If either file is stale, jump straight to Step 2 to check the sync job logs before investigating further.

---

## Step 2 — Check weather-sync Cloud Run job

### 2a. Confirm last execution succeeded

```
https://console.cloud.google.com/run/jobs/details/us-central1/weather-sync/executions?project=fg-polylabs
```

The most recent execution should show status **Succeeded** and a start time of today ~03:00 UTC.

### 2b. Review logs for errors

Click the most recent execution → **Logs** tab, or go directly:

```
https://console.cloud.google.com/run/jobs/details/us-central1/weather-sync/executions?project=fg-polylabs
```

Filter by severity **ERROR** or **WARNING**. A healthy run should end with log lines confirming:
- Rows exported from BigQuery
- Upload to GCS complete
- Push to GitHub complete

---

## Step 3 — Check doomsday-polymarket Cloud Run job

### 3a. Confirm last execution succeeded

```
https://console.cloud.google.com/run/jobs/details/us-central1/doomsday-polymarket/executions?project=fg-polylabs
```

The most recent execution should show status **Succeeded** and a start time of today ~01:00 UTC.

### 3b. Review logs for errors

Click the most recent execution → **Logs** tab.

Look for any ERROR-level lines. A healthy run logs per-city fetch progress and a final summary row count written to BigQuery.

### 3c. Verify data landed in BigQuery

Run this query in the BigQuery console to confirm data is present and recent:

```sql
SELECT
  MAX(date) AS most_recent_market_date,
  COUNT(*) AS total_rows
FROM `fg-polylabs.weather.polymarket_snapshots`;
```

> Open BigQuery: https://console.cloud.google.com/bigquery?project=fg-polylabs

Expected: `most_recent_market_date` within the last ~14 days. Note: the `date` column is the Polymarket market event date (not ingestion time), so it reflects the furthest-out open market, not today's date. If the result is empty or very stale (>14 days), check the polymarket job logs (Step 3b).

---

## Step 4 — Verify weather-api service is live

### 4a. Metrics / health

```
https://console.cloud.google.com/run/detail/us-central1/weather-api/observability/metrics?project=fg-polylabs
```

Confirm:
- **Instance count** > 0 (or auto-scaled to 0 but with recent request activity)
- **Request latency** looks normal (no spikes)
- **Error rate** is at or near 0%

### 4b. Quick smoke test

Hit the health endpoint directly (replace with your actual health route if different):

```bash
curl -s -o /dev/null -w "%{http_code}" https://<weather-api-url>/health
```

Expected: `200`. Any 5xx means the service is down.

> Find the service URL: https://console.cloud.google.com/run/detail/us-central1/weather-api/revisions?project=fg-polylabs

---

## Quick-reference checklist

```
[ ] 1a. snapshots.jsonl commit on GitHub is today
[ ] 1b. tracked_cities.jsonl commit on GitHub is today
[ ] 1c. snapshots.jsonl in GCS updated today
[ ] 1d. tracked_cities.jsonl in GCS updated today
[ ] 2a. weather-sync last execution = Succeeded
[ ] 2b. weather-sync logs have no ERRORs
[ ] 3a. doomsday-polymarket last execution = Succeeded
[ ] 3b. doomsday-polymarket logs have no ERRORs
[ ] 3c. BigQuery has rows for yesterday
[ ] 4a. weather-api metrics look healthy
[ ] 4b. weather-api smoke test returns 200
```

---

## Triage guide

| Symptom | Likely cause | First action |
|---------|-------------|-------------|
| GCS/GitHub files stale, sync job succeeded | Sync job ran but push step errored silently | Check sync job logs for push/upload errors |
| Sync job failed | Upstream BigQuery data missing (doomsday-polymarket didn't run) | Check doomsday-polymarket job first (Step 3) |
| doomsday-polymarket succeeded but BQ market date is stale | No new Polymarket markets listed beyond that date | Normal if markets haven't been opened; check Polymarket for new listings |
| weather-api 5xx | Bad deploy or OOM | Check Logs tab on the service revision |
| All jobs fine but admin UI shows stale data | Browser cache or source locked to GitHub | Click "GCS" source button or hard-refresh |

---

## Asking Claude to run this check

When asking Claude Code to validate the application, say:

> "Run the daily health check"

Claude will execute `scripts/health-check.sh`, which automates all six steps above and prints a `[PASS]` / `[FAIL]` / `[WARN]` result for each check, followed by a summary. Any failures are reported with detail so the triage guide above can be applied immediately.

## Running the script manually

```bash
bash scripts/health-check.sh
```

Requires `gcloud` to be authenticated (`gcloud auth login`) and pointed at the `fg-polylabs` project. The BigQuery step is skipped automatically if the `bq` CLI is unavailable.
