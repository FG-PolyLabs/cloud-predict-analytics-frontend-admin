# TODO — cloud-predict-analytics

Shared task list across all three repos. Update this file as work progresses.
Claude should read this at the start of each session to pick up context.

Last updated: 2026-03-30 (session 6)

---

## Next Up

- [x] **Backfill actual_max_temp_c for past target_dates** ✓ 2026-03-30
  - Added `--backfill-actuals` flag to `cmd/nbm/main.go`.
  - Source: Open-Meteo archive API (same coordinates as forecasts, UTC daily max — no airport mapping needed).
  - Queries BQ for `(city, target_date)` pairs with NULL actuals where `target_date < TODAY`,
    fetches via archive, merges back with `error_c = predicted - actual`.
  - Cloud Run job updated: `--all-cities,--forecast-days=10,--backfill-actuals`.
  - Dates not yet in archive (e.g. yesterday) are silently skipped and retried next run.

- [ ] **Add weather-nbm to health-check.sh**
  - Add a Step 7 checking the `weather-nbm` Cloud Run job last execution and BQ row count.

- [ ] **Alert on data staleness**
  - When no new snapshots land for N consecutive days, surface a warning in the admin UI.

---

## Backlog

- [x] **NBM bin probabilities: store raw member temps** ✓ 2026-03-30
  - Added `member_temps REPEATED FLOAT64` to `nbm_forecasts` schema.
  - `cmd/nbm/main.go` stores raw 30-member values; `ensureColumns()` auto-migrates existing table.
  - API returns `member_temps` array; frontend uses empirical distribution (count/30 per bin).
  - Modal now shows exact member counts in tooltips + threshold query: "P(high ≥ X°C) = N/30 members".



- [ ] **Investigate weather-polymarket job failure**
  - Daily Polymarket fetch job failed (noted 2026-03-29). Check Cloud Run logs,
    determine if it's a transient error or a code/data issue, and fix.

- [ ] **NBM page: forecast evolution chart (multi-line by forecast_date)**
  - Currently the page filters to a single forecast_date (default today), so there's one
    line per city. The desired view: one line per forecast_date for a selected city, showing
    how the 10-day prediction evolves as each new daily forecast comes in.
  - Requires:
    1. API: change /nbm-forecasts to accept forecast_date_from/forecast_date_to range
       instead of a single forecast_date (or add a separate mode).
    2. Frontend: require city selection (multi-line by city doesn't make sense here);
       group chart datasets by forecast_date; x-axis = target_date; each line = one
       forecast_date's predictions. Std dev / p10-p90 bands per line optional.
  - Good to build once a few days of data have accumulated (currently only 2026-03-29).

- [ ] **Admin UI: Overlay Polymarket YES% on NBM chart**
  - Once the evolution chart is built, overlay actual Polymarket YES% for the matching
    threshold bracket so you can visually compare forecast uncertainty vs market pricing.

- [ ] **Auto-discover new Polymarket markets for tracked cities**
  - Discovery source: https://polymarket.com/weather/temperature
  - Should log newly found cities rather than auto-add (human review before tracking).

---

## Recently Completed (2026-03-30, session 6)

- [x] **Backfill actual_max_temp_c / error_c** — `--backfill-actuals` flag added to `cmd/nbm/main.go`
  - Open-Meteo archive API; same coords as forecasts; no airport mapping
  - MERGE updates all forecast_date rows for a (city, target_date) in one pass
  - Cloud Run job + build.yml updated to pass `--backfill-actuals` daily

## Recently Completed (2026-03-30, session 5)

- [x] **NBM page: 1-degree bin probability distribution modal**
  - "~" button on each table row opens a modal bar chart showing probability per 1-degree bin.
  - Computed entirely on the frontend from `predicted_max_temp_c` (μ) and `temp_std_dev_c` (σ)
    using the normal CDF (Abramowitz & Stegun approximation). No new table or API changes needed.
  - Bins with <1% probability omitted. Bin containing μ highlighted in darker blue.
  - Label format: "15–16°C → X.XX%"

## Recently Completed (2026-03-29)

- [x] `weather-nbm` Cloud Run job created and scheduled (daily 00:30 UTC)
- [x] CI pipeline fixed: GITHUB_TOKEN removed from update-env-vars (already in Secret Manager)
- [x] nbm_forecasts schema extended: skewness, p10_temp_c, p90_temp_c, actual_max_temp_c, error_c
  - skewness: third standardized moment (>0 = hot tail, <0 = cold tail)
  - p10/p90: 10th/90th percentile across 30 GFS ensemble members
  - actual_max_temp_c / error_c: nullable, filled retrospectively once date passes
- [x] MERGE fixed: switched from INSERT ROW (positional) to explicit named INSERT
  - Root cause: INSERT ROW is positional; ALTER TABLE appended new cols at end of target
    while nbmSchema() placed them in the middle — caused type mismatch on member_count

---

## Previously Completed (2026-03-28)

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
