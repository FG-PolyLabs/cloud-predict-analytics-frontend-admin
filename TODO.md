# TODO — cloud-predict-analytics

Shared task list across all three repos. Update this file as work progresses.
Claude should read this at the start of each session to pick up context.

Last updated: 2026-03-28 (session 3)

---

## Pick Up Here (session interrupted 2026-03-28)

### 1. Create weather-nbm Cloud Run job (manual step — not yet done)

The `weather-nbm` binary is built and deployed to the image via `build.yml`,
but the Cloud Run Job itself hasn't been created yet. Run once:

```bash
gcloud run jobs create weather-nbm \
  --image=us-central1-docker.pkg.dev/fg-polylabs/polymarket/polymarket:latest \
  --command=/app/nbm \
  --args="--all-cities,--forecast-days=10" \
  --region=us-central1 \
  --service-account=weather-runner@fg-polylabs.iam.gserviceaccount.com \
  --task-timeout=10m \
  --max-retries=2 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=fg-polylabs" \
  --project=fg-polylabs
```

Then schedule it daily at 00:30 UTC via Cloud Scheduler:

```bash
gcloud scheduler jobs create http weather-nbm-daily \
  --schedule="30 0 * * *" \
  --uri="https://cloudrun.googleapis.com/v2/projects/fg-polylabs/locations/us-central1/jobs/weather-nbm:run" \
  --message-body="{}" \
  --oauth-service-account-email=weather-runner@fg-polylabs.iam.gserviceaccount.com \
  --location=us-central1 \
  --project=fg-polylabs
```

### 2. Run the first nbm job manually and validate

```bash
gcloud run jobs execute weather-nbm --region=us-central1 --project=fg-polylabs --wait
```

Then query BQ to confirm data landed:

```sql
SELECT city, target_date, forecast_date, lead_days,
       predicted_max_temp_c, temp_std_dev_c, member_count
FROM weather.nbm_forecasts
ORDER BY city, target_date, forecast_date
LIMIT 50;
```

Expected: 12 cities × 10 days = 120 rows, all with `member_count=30`.

### 3. Verify the Mar 10-26 polymarket backfill finished

Execution `weather-polymarket-8npsj` was running when session ended (~20:15 UTC).
Check status:

```bash
gcloud run jobs executions describe weather-polymarket-8npsj \
  --region=us-central1 --project=fg-polylabs \
  --format="value(status.conditions[0].type, status.conditions[0].status, status.completionTime)"
```

If `Completed/False`, check logs for partial failures (missing cities on some dates is normal).
Then run:

```bash
python3 scripts/data-report.py --latest
```

Expected: all 12 cities showing recent data. Then trigger weather-sync to push to GCS/GitHub.

---

## Blocked / Action Required

- [x] **weather-polymarket job was running the wrong binary** *(fixed 2026-03-27)*
- [x] **Job name mismatch in health-check.sh** *(fixed 2026-03-27)*
- [x] **temp_threshold=0 for all range markets (e.g. "between 68-69°F")** *(fixed 2026-03-28)*
  - Root cause: `extractTempThreshold` called `ParseFloat("68-69")` which fails → returned 0.
  - Fix: `strings.LastIndex(token, "-")` strips the lower bound, leaving just the upper ("69").
  - Also fixed: `--no-volume` now bypasses Filter 1 (VolumeTotal==0) so resolved markets
    can be backfilled via the CLOB price history API.
  - Also fixed: `runAllCities` returns error instead of `log.Fatalf`, so date-range backfill
    continues past dates where some cities have no Polymarket event.
  - Backfill: Feb 3–Mar 9 complete. Mar 10–26 backfill (`weather-polymarket-8npsj`) was in
    progress when session ended. 29,456 bad threshold=0 rows were deleted before re-collection.

---

## Next Up

- [ ] **Add actual temperature to nbm_forecasts (accuracy tracking)**
  - Once the nbm job is running and collecting forecasts, add a second daily job (or extend
    the nbm job) to backfill `actual_max_temp_c` for past target_dates.
  - Source: Iowa State Mesonet API (ASOS) — use nearest airport to each city.
  - City → airport mapping needed (e.g. dallas → KDFW, nyc → KJFK, london → EGLL).
  - Derived fields: `error_c = predicted - actual`, `abs_error_c`.
  - This enables the core analysis: does forecast std_dev correlate with Polymarket spread?

- [ ] **Add weather-nbm to health-check.sh**
  - Add a Step 7 checking the `weather-nbm` Cloud Run job last execution and BQ row count.

- [ ] **Verify health-check.sh BQ step handles "job ran but no new markets" gracefully**
  *(already done 2026-03-28 — keeping for reference)*

- [ ] **Alert on data staleness**
  - When no new snapshots land for N consecutive days, surface a warning in the admin UI.

---

## Backlog

- [ ] **Auto-discover new Polymarket markets for tracked cities**
  - Discovery source: https://polymarket.com/weather/temperature
  - Should log newly found cities rather than auto-add (human review before tracking).

- [ ] **Admin UI: NBM forecast tab**
  - Add a tab to the snapshots page (or a new section) showing `nbm_forecasts` data:
    - Chart: predicted_max_temp_c over lead_days for a given city/target_date
    - Overlay: temp_std_dev_c as a shaded band
    - Overlay: actual Polymarket YES% for the winning threshold bracket
  - Data source: new `/nbm-forecasts` API endpoint in weather-api.

---

## Recently Completed (2026-03-28)

- [x] Polymarket threshold extraction fix (`extractTempThreshold` handles "X-Y°F" ranges)
- [x] Backfill filter fix (`--no-volume` bypasses VolumeTotal==0 check for resolved markets)
- [x] Backfill continuity fix (`runAllCities` returns error instead of Fatalf in date-range mode)
- [x] `weather-nbm` job implemented (`cmd/nbm/main.go`) — GFS ensemble → BQ `nbm_forecasts`
  - 30-member GFS ensemble via Open-Meteo, computes mean + sample std dev per day
  - MERGE key: (city, target_date, forecast_date); updates on re-run
  - Table auto-created on first run; day-partitioned on target_date
- [x] Snapshots page default date range: yesterday → today
- [x] health-check.sh: "no markets found" failures now WARN not FAIL
- [x] daily-health-check.md: Step 3d added for data-report.py
- [x] `scripts/data-report.py` — per-city snapshot coverage report (2026-03-27)
- [x] `scripts/health-check.sh` — daily health check script
- [x] `weather-sync` job — daily BQ → GCS + GitHub export
- [x] `weather-polymarket` job — daily Polymarket fetch → BigQuery
