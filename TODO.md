# TODO — cloud-predict-analytics

Shared task list across all three repos. Update this file as work progresses.
Claude should read this at the start of each session to pick up context.

Last updated: 2026-03-28 (session 2)

---

## Blocked / Action Required

- [x] **weather-polymarket job was running the wrong binary — no data collected since job creation** *(fixed 2026-03-27)*
  - Root cause: the Cloud Run job had no `--command` override, so it ran the image's default
    ENTRYPOINT (`./api`, the web server) instead of `./polymarket`. The API server ignored
    `--all-cities --yesterday` and sat idle for 90 min until task timeout on every daily run.
  - Fix: set `--command=/app/polymarket` on the live job via `gcloud run jobs update`, and
    added `--command=/app/polymarket --args="--all-cities,--yesterday"` to both `build.yml`
    and `scripts/setup.sh` so future deploys/provisioning preserve it.
  - Validated: manual run on 2026-03-28 collected **6,726 snapshots across 12/12 cities**
    for market date 2026-03-27. BQ table at 80,807 total rows.

- [x] **Job name mismatch: `health-check.sh` monitored the wrong Cloud Run job** *(fixed 2026-03-27)*
  - Was: `health-check.sh` queried `weather-polymarket`; actual deployed job is `weather-polymarket`.
  - Fixed: renamed all references in `health-check.sh`, `CLAUDE.md`, and `docs/daily-health-check.md`
    to `weather-polymarket` (matching `build.yml` and `setup.sh`).
  - Also fixed: BQ staleness check (Step 5) now downgrades from FAIL → WARN when the
    polymarket job itself also failed, so correlated failures don't double-count.

---

## Pick Up Here (session interrupted 2026-03-28)

- [x] **Run `weather-polymarket` job and validate per-city data for yesterday (2026-03-27)**
  - User restarted to fix gcloud/bq CLI install. Resume by:
    1. `gcloud run jobs execute weather-polymarket --region=us-central1 --project=fg-polylabs --wait`
    2. Query BQ per-city row counts for `date = '2026-03-27'` using `bq` CLI (REST API had
       escaping issues on Windows — use `bq query` instead)
    3. Run `bash scripts/health-check.sh` — expect all green except weather-sync Steps 1-3
       if sync hasn't run yet today (runs at 03:00 UTC)
    4. Pull the data repo and run `python3 scripts/data-report.py 2026-03-27` once sync runs
  - Context: BQ table confirmed at 80,807 rows, last modified 2026-03-28 02:32 UTC from an
    earlier manual run (execution `weather-polymarket-hwft7`). If re-running, the MERGE will
    skip duplicates and report 0 new rows — that's expected if we already ran it today.
  - Use `bq query` not REST API for per-city breakdowns — REST API date literals had shell
    escaping issues on Windows.

---

## Next Up

- [x] **Verify health-check.sh BQ step handles the "job ran but no new markets" case gracefully** *(fixed 2026-03-28)*
  - Step 4 now greps logs for "no markets found" / "could not find event" before reporting status.
    If detected: execution and log checks downgrade from FAIL → WARN with a clear message.
  - Step 5 BQ check has a new `poly_no_markets` branch that WARNs with "polymarket found no
    markets for target date, table not touched" — distinct from the generic "also failed" WARN.

- [x] **Add `data-report.py` to the daily health check runbook** *(done 2026-03-28)*
  - Added Step 3d to `docs/daily-health-check.md` with usage examples for `--date` and `--latest`.
  - Added checklist item `3d` and a triage row for the "no markets found" case.

---

## Backlog

- [ ] **Auto-discover new Polymarket markets for tracked cities**
  - Discovery source: https://polymarket.com/weather/temperature — find cities listed there
    that are not yet in our `tracked_cities` table and surface them for review/addition.
  - This could be a periodic check in `weather-polymarket` or a separate lightweight job.
  - Should log newly found cities rather than auto-add them (human review before tracking).

- [ ] **NBM temperature prediction pipeline — new BQ table**
  - Fetch live National Blend of Models (NBM) forecast data and store it in a new BigQuery
    table (dataset `weather`, e.g. `nbm_forecasts`).
  - Schema goal: capture the NBM predicted temperature at specific forecast hours (e.g.
    predicted high at noon) per city per date, including the forecast issuance time so we
    can track how predictions evolve as the target date approaches.
  - Accuracy tracking (same table or a derived table):
    - `predicted_temp`: what NBM said the temp would be at noon on date D
    - `actual_temp`: what was actually recorded (source: nearest airport ASOS/METAR data)
    - Derived fields: error, absolute error, which enables std-dev analysis across cities
      and forecast lead times
  - Airport data source: use ASOS/METAR airport observations for actuals (NOAA ISD or
    Iowa State Mesonet API are good sources; match each tracked city to its nearest airport)
  - Downstream use: feed into analysis of Polymarket pricing vs. NBM forecast accuracy —
    does the market price correlate with forecast uncertainty (wide std-dev = more spread)?

- [ ] **Alert on data staleness**
  - When no new snapshots land for N consecutive days, surface a warning somewhere (email,
    Slack, or just a visible flag in the admin UI on the snapshots page).

---

## Recently Completed

- [x] `scripts/data-report.py` — per-city snapshot coverage report, supports `--date` and
      `--latest` (2026-03-27)
- [x] `scripts/health-check.sh` — automated daily health check for all six system components
      (GCS, GitHub, both Cloud Run jobs, BigQuery, weather-api) (2026-03-25 ish)
- [x] `docs/daily-health-check.md` — runbook for manual and scripted health checks
- [x] Collapsible resources panel in navbar
- [x] Reset Table button on snapshots page
- [x] Backfill modal on snapshots page
- [x] Chart/table toggle + date range filter on snapshots page
- [x] Source cascade (GitHub → GCS → API) with manual source lock buttons
- [x] `weather-sync` job — daily BQ → GCS + GitHub export
- [x] `weather-polymarket` job — daily Polymarket fetch → BigQuery
