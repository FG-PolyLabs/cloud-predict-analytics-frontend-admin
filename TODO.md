# TODO — cloud-predict-analytics

Shared task list across all three repos. Update this file as work progresses.
Claude should read this at the start of each session to pick up context.

Last updated: 2026-03-31 (session 9)

---

## In Progress (session 9)

- [x] **Rename "NBM Forecasts" → "Open-Meteo Forecasts" throughout frontend** ✓ 2026-03-31
  - Renamed content dir, layout dir, navbar link, page title, auth-guard message.
  - Backend: added `/open-meteo-forecasts` route alias in `internal/api/server.go`; old `/nbm-forecasts` kept for compatibility.
  - The underlying model is GFS seamless via Open-Meteo — not NOAA's NBM.

- [ ] **Research + design new forecast model ingestion pipelines**
  - Raw data principle: new ingest jobs store API output as-is; no derived stats computed at ingest.
  - Models to add (see Backlog → Forecast Model Expansion).

---

## Next Up

- [x] **Backfill actual_max_temp_c for past target_dates** ✓ 2026-03-30
  - Added `--backfill-actuals` flag to `cmd/nbm/main.go`.
  - Source: Open-Meteo archive API (same coordinates as forecasts, UTC daily max — no airport mapping needed).
  - Queries BQ for `(city, target_date)` pairs with NULL actuals where `target_date < TODAY`,
    fetches via archive, merges back with `error_c = predicted - actual`.
  - Cloud Run job updated: `--all-cities,--forecast-days=10,--backfill-actuals`.
  - Dates not yet in archive (e.g. yesterday) are silently skipped and retried next run.

- [ ] **ensureColumns bug: member_temps not auto-migrated on first run**
  - The `ensureColumns()` schema migration in `cmd/nbm/main.go` silently failed to add
    `member_temps` — column had to be added manually via BQ REST API.
  - Root cause unknown (possibly ETag conflict or BQ Go client issue). Investigate and fix
    so future schema additions work automatically without manual intervention.

- [ ] **Rebuild nbm.exe before running manually after code changes**
  - Reminder: `go build -o nbm.exe ./cmd/nbm/` must be run after any code change.
    The old binary was used inadvertently, producing rows with empty member_temps.
  - Consider adding a note to CLAUDE.md or runbook about this.

- [x] **Add weather-nbm to health-check.sh** ✓ 2026-03-30
  - Added Step 7: checks `weather-nbm` last execution + error logs + `nbm_forecasts` BQ table metadata.

- [ ] **Alert on data staleness**
  - When no new snapshots land for N consecutive days, surface a warning in the admin UI.

---

## Backlog

---

### Forecast Model Expansion

**Design principle:** Ingest jobs store raw API/GRIB output only. Derived stats (mean, std dev,
skewness, percentiles) are computed at query time or in the frontend — not baked in at ingest.

- [x] **[Models] ECMWF ensemble via Open-Meteo — new BQ table + admin dashboard** ✓ 2026-03-31
  - Model: `ecmwf_ifs025` (51 members, ~25 km global, best-in-class NWP skill)
  - `cmd/ecmwf/main.go` — fetches raw member arrays from Open-Meteo, writes to BQ `ecmwf_forecasts`
  - Schema: city, target_date, forecast_date, lead_days, member_count, member_temps[], model, fetched_at, actual_max_temp_c, error_c (no pre-computed stats)
  - `internal/api/ecmwf.go` — `GET /ecmwf-forecasts` handler; returns raw rows
  - Frontend: `content/ecmwf-forecasts/` + layout; stats (mean, σ, p10/p90, skewness) computed from member_temps in JS via `enrichRow()`
  - Dockerfile + build.yml updated to build/deploy `weather-ecmwf` Cloud Run job
  - **Still needed:** Create `weather-ecmwf` Cloud Run job in GCP + schedule at 00:45 UTC (see setup.sh pattern from weather-nbm)

- [ ] **[Models] ICON ensemble via Open-Meteo — new BQ table + admin dashboard**
  - Model: `icon_seamless` (DWD, ~13 km, 40 members, strong in Europe)
  - Same approach as ECMWF above; BQ table `icon_forecasts`
  - New admin page: `content/icon-forecasts/`

- [ ] **[Models] Real NOAA NBM data — new BQ table + admin dashboard**
  - Source: AWS S3 public bucket `s3://noaa-nbm-grib2-pds/` (no auth required)
  - File pattern: `blend.YYYYMMDD/HH/core/blend.tHHz.core.fFFF.co.grib2` (CONUS only)
  - Format: GRIB2 — requires `cfgrib` (Python) or `wgrib2` CLI to parse
  - **US-only limitation:** NBM covers CONUS/AK/HI only → applicable cities: chicago, dallas, miami, nyc
    (toronto is Canada and would need the separate `blend.*.ak.grib2` — not covered; skip)
  - Raw fields to store: `tmax_mean`, `tmax_spread`, `tmax_p10`, `tmax_p25`, `tmax_p50`, `tmax_p75`, `tmax_p90`
    — these are what NBM publishes; individual members are NOT available (NBM is already a blend)
  - BQ table: `nbm_noaa_forecasts` — schema: city, target_date, forecast_date (model run date),
    lead_days, model_run_hour, tmax_mean_c, tmax_spread_c, tmax_p10_c, tmax_p25_c, tmax_p50_c,
    tmax_p75_c, tmax_p90_c, fetched_at
  - Implementation: Python Cloud Run job (easier GRIB2 tooling than Go)
  - New admin page: `content/nbm-noaa-forecasts/`
  - Note: since NBM doesn't expose raw members, "raw" here means storing the published GRIB fields
    without further transformation — no client-side stats needed beyond what NBM already provides

- [ ] **[Models] Tomorrow.io ensemble forecasts — new BQ table + admin dashboard + market-edge source**
  - API: `GET https://api.tomorrow.io/v4/weather/forecast?location={lat},{lon}&timesteps=1d&apikey={key}`
  - Free tier: 500 calls/day, 25/hour — feasible for 12 cities × 10-day horizon (~120 calls/run)
  - **Ensemble exposure:** Tomorrow.io exposes a probabilistic forecasting endpoint (21–51 members
    depending on tier); investigate whether free tier includes PDF/confidence interval fields or
    only deterministic `temperatureMax`. If probabilistic is paid-only, fall back to deterministic
    storage (same schema as Pirate Weather / OWM below) and use analytical fit in market-edge UI.
  - **If ensemble data is available:** store raw member arrays exactly like `open_meteo_forecasts`
    — member_temps[], member_count; bracket probability computed client-side from member counts.
  - **If deterministic only:** store point forecast + any spread/confidence fields returned:
    `tmax_c`, `tmax_low_c` (10th pct), `tmax_high_c` (90th pct) if available; use analytical
    fit in market-edge UI (no Raw Members% column — Fit% only).
  - BQ table: `tomorrow_forecasts`
  - Schema (deterministic): city, target_date, forecast_date, lead_days, tmax_c, tmax_low_c,
    tmax_high_c, model, fetched_at, actual_max_temp_c, error_c
  - Schema (ensemble): same as `open_meteo_forecasts` — city, target_date, forecast_date,
    lead_days, member_count, member_temps[], model, fetched_at, actual_max_temp_c, error_c
  - Backend: new Cloud Run job `weather-tomorrow` (`cmd/tomorrow/main.go`)
  - Admin page: `content/tomorrow-forecasts/`
  - **Market-edge integration:** add Tomorrow.io as a selectable source (see multi-source TODO below)
  - API key: store in Secret Manager as `TOMORROW_API_KEY`; add to Cloud Run job env

- [ ] **[Models] Pirate Weather deterministic forecasts — new BQ table + admin dashboard + market-edge source**
  - API: `GET https://api.pirateweather.net/forecast/{key}/{lat},{lon}?exclude=currently,minutely,hourly,alerts`
  - Free tier: 20,000 calls/month (~667/day) — well within budget for 12 cities daily
  - **No ensemble exposure:** uses GEFS 30-member ensemble internally but only returns deterministic
    daily output. Store point forecast only; market-edge UI uses analytical fit.
  - Daily max field: `daily.data[].temperatureHigh` (in °F by default — convert to °C at ingest)
  - Additional fields worth storing: `temperatureLow`, `temperatureHighTime`, `precipProbability`,
    `precipIntensity`, `precipType`, `windSpeed`, `humidity`, `icon`
  - BQ table: `pirate_weather_forecasts`
  - Schema: city, target_date, forecast_date, lead_days, tmax_c, tmin_c, precip_prob,
    precip_intensity, wind_speed, humidity, icon, fetched_at, actual_max_temp_c, error_c
  - Backend: new Cloud Run job `weather-pirate` (`cmd/pirate/main.go`)
  - Admin page: `content/pirate-weather-forecasts/`
  - **Market-edge integration:** deterministic source — Fit%-only in market-edge UI (no Members%);
    σ estimated from historical error distribution for this source (see calibration TODO below)
  - API key: store in Secret Manager as `PIRATE_WEATHER_API_KEY`; add to Cloud Run job env
  - Note: dark-sky-compatible API — response shape closely mirrors Dark Sky JSON

- [ ] **[Models] OpenWeatherMap deterministic forecasts — new BQ table + admin dashboard + market-edge source**
  - API: `GET https://api.openweathermap.org/data/3.0/onecall?lat={lat}&lon={lon}&exclude=current,minutely,hourly,alerts&units=metric&appid={key}`
  - Free tier: 1,000 calls/day — plenty of headroom for 12 cities
  - **No ensemble exposure:** deterministic point forecast only; use analytical fit in market-edge UI
  - Daily max field: `daily[].temp.max` (°C when `units=metric`)
  - Additional fields: `daily[].temp.min`, `daily[].temp.morn/day/eve/night`, `daily[].feels_like`,
    `daily[].pop` (precip prob), `daily[].wind_speed`, `daily[].humidity`, `daily[].weather[0].main`
  - BQ table: `owm_forecasts`
  - Schema: city, target_date, forecast_date, lead_days, tmax_c, tmin_c, precip_prob,
    wind_speed, humidity, weather_main, fetched_at, actual_max_temp_c, error_c
  - Backend: new Cloud Run job `weather-owm` (`cmd/owm/main.go`)
  - Admin page: `content/owm-forecasts/`
  - **Market-edge integration:** deterministic source — Fit%-only in market-edge UI (no Members%)
  - API key: store in Secret Manager as `OWM_API_KEY`; add to Cloud Run job env
  - Note: OWM One Call 3.0 requires a credit card on file; billed only above 1K calls/day

- [ ] **[Models] Generalize ingestion: consider a single `open_meteo_forecasts` table with `model` column**
  - Instead of separate tables per Open-Meteo model (ecmwf, icon, gfs), a single table with
    a `model STRING` column reduces schema duplication. Evaluate after ECMWF job is built.

- [ ] **[Models] Per-source σ calibration for deterministic forecasts (Pirate Weather, OWM)**
  - Deterministic sources (Pirate Weather, OWM) have no ensemble spread, so the market-edge
    Fit% column needs a σ estimate to fit a distribution over the bracket.
  - Approach: after accumulating ≥30 days of `actual_max_temp_c` vs `tmax_c`, compute
    rolling historical RMSE per (city, lead_days) bucket. Use RMSE as σ in the normal/skew-normal
    fit for that source+city+lead combination.
  - Store calibration outputs in a BQ table `source_calibration`:
    city, source, lead_days_bucket (1-3, 4-7, 8-10), rmse_c, bias_c, n_samples, computed_at
  - Market-edge UI reads calibration via a new `/source-calibration` API endpoint and uses
    the matching RMSE as σ when computing Fit% for deterministic sources.
  - Initially: fall back to a fixed σ = 2.5°C (reasonable prior for 1-week lead) until
    enough data has accumulated for empirical calibration.

---

### Market Edge UI — Multi-Source Support

- [ ] **[Market Edge] Add source selector to market-edge comparison UI**
  - Currently hardcoded to Open-Meteo GFS (`/nbm-forecasts` endpoint).
  - As new forecast sources come online (Tomorrow.io, Pirate Weather, OWM, ECMWF), the
    comparison UI should let the user pick which model to compare against Polymarket prices.
  - **UX:** Add a "Model" dropdown next to the city/date controls. Options populated from a
    static list in JS (same pattern as CITIES const). Initially: Open-Meteo GFS, ECMWF IFS.
    Add new entries as each ingest job ships.
  - **Table columns per source type:**
    - *Ensemble source* (Open-Meteo GFS, ECMWF, Tomorrow.io if probabilistic): show
      Members%, Members count, Raw Edge, ROI, Fit%, Fit Edge, Fit ROI — current full layout.
    - *Deterministic source* (Pirate Weather, OWM, Tomorrow.io if deterministic-only): hide
      Members% and Members columns (show "—"); show only Fit%, Fit Edge, Fit ROI.
      Use calibrated σ (from `source_calibration` table) or fixed σ = 2.5°C fallback.
  - **API routing:** each source maps to its own backend endpoint
    (`/nbm-forecasts`, `/ecmwf-forecasts`, `/tomorrow-forecasts`, `/pirate-forecasts`, `/owm-forecasts`).
    The `loadComparison()` function picks the endpoint based on the selected model.
  - **Blocker:** depends on at least one new ingest job being live and returning data.

---

### Product 1 — Open-Meteo Ensemble vs Polymarket comparison UI

> Previously called "NBM vs Polymarket" — renamed to reflect actual data source.
> The ensemble data is GFS seamless (30 members) via Open-Meteo, not NOAA NBM.

**Goal:** A decision-support tool. Pick a city, see the Open-Meteo GFS ensemble probability per temperature bracket side-by-side with Polymarket's YES/NO prices for that bracket — so you can spot mispricing and decide whether to bet.

- [ ] **[Product 1] Open-Meteo Ensemble × Polymarket comparison page (admin tab first, standalone app later)**

  **UX flow:**
  1. User selects a city (e.g. Miami).
  2. Clicks "Load" — fetches today's Open-Meteo GFS ensemble forecast + all open Polymarket markets for that city.
  3. Page renders one row per (target_date × temperature bracket):
     - **Ensemble empirical probability** — `member_count_in_bracket / 30` (e.g. 3/30 = 10%)
     - **Polymarket YES price** (implied probability of that bracket resolving YES)
     - **Polymarket NO price** (= 1 − YES price roughly)
     - **Edge** — difference between ensemble probability and Polymarket YES price (positive = model says more likely than market implies)
  4. Table sortable by edge; chart option: grouped bars per target_date (ensemble% vs Polymarket YES%).

  **Data sourcing:**
  - Access-controlled: restricted to authorized emails via Firebase Auth (same whitelist as
    admin site). Not public — no GCS/GitHub export needed.
  - Ensemble data: fetched from `weather-api /open-meteo-forecasts` with Firebase ID token (same `api()`
    helper pattern as admin). No new public endpoint or GCS export required.
  - Polymarket data: Polymarket exposes a public REST API — fetch directly from browser JS,
    no backend proxy needed.
  - **Decision:** both admin tab and future standalone app hit `weather-api` directly with auth.
    Standalone app = new repo (e.g. `cloud-predict-analytics-frontend`) with its own Firebase
    Auth setup but same `ALLOWED_EMAILS` whitelist and same API.

  **Bracket alignment:**
  - Polymarket markets are defined per temperature bracket (e.g. "Will Miami high be 24–25°F?").
    Need to map market bracket → matching ensemble 1°C bins and sum their probabilities.
  - Bracket definitions vary by market; need to parse them from market titles (the
    `extractTempThreshold` logic already exists in `weather-polymarket` job).

  **Admin tab:** Add as a new content section `content/ensemble-vs-market/_index.md` + layout.
  Standalone app: new repo under FutureGadgetLabs when ready to productionize.

---

### Product 2 — ML opportunity detection (analytics backend)

**Goal:** Given a snapshot of today's Open-Meteo GFS ensemble forecast and Polymarket prices, predict whether there is a positive-edge betting opportunity based on how well the model has been calibrated historically.

- [ ] **[Product 2, data] Add `realized_highs` BQ table**

  Standalone source-of-truth for observed daily max temperatures.
  - Schema: `city STRING, date DATE, actual_max_temp_c FLOAT64, source STRING` (e.g. "open-meteo-archive")
  - Populated by a new `--backfill-realized` mode (or repurpose `--backfill-actuals`) in `cmd/nbm/main.go`.
  - Note: `open_meteo_forecasts.actual_max_temp_c` stores the same data but denormalized across
    all forecast_date rows per (city, target_date). `realized_highs` is the deduplicated
    canonical record — one row per (city, date).
  - `weather-sync` should export this table to GCS + GitHub alongside existing exports.

- [ ] **[Product 2, data] Add `ensemble_market_features` BQ view (feature engineering layer)**

  A BQ view (not a table — derived on-demand) joining:
  - `open_meteo_forecasts` — raw member_temps per (city, target_date, forecast_date)
  - `polymarket_snapshots` — YES/NO prices per (city, target_date, bracket, snapshot_time)
  - `realized_highs` — actual outcome per (city, target_date)

  Key derived columns:
  - `ensemble_bracket_prob` — fraction of members falling within the Polymarket bracket
  - `market_yes_price` — Polymarket implied YES probability at snapshot time
  - `edge` — `ensemble_bracket_prob − market_yes_price`
  - `resolved_yes` — 1 if actual high fell within bracket, 0 otherwise (nullable until resolved)
  - `lead_days` — days from forecast_date to target_date (model accuracy degrades with lead)

  This view is the training dataset for all ML models.

- [ ] **[Product 2, ML] Build calibration model and `ml_opportunity_scores` BQ table**

  **What the model predicts:** Given (city, target_date, bracket, snapshot_date), is the Open-Meteo
  ensemble's probability well-calibrated vs. the Polymarket price? If the ensemble says 30% and the
  market says 15%, is that a real edge or is the model systematically overconfident at
  this lead time / city / temperature range?

  **Architecture:**
  - Python Cloud Run job (`cmd/ml` or `scripts/ml_score.py`) — runs on demand or daily.
  - Reads `ensemble_market_features` from BQ as training/inference data.
  - Model: start simple — logistic regression or isotonic regression to calibrate ensemble
    probabilities against historical `resolved_yes` outcomes, grouped by lead_days bucket.
  - Outputs written to new BQ table `ml_opportunity_scores`:

  ```
  city STRING
  target_date DATE
  bracket STRING                   -- e.g. "24–25°C"
  snapshot_date DATE
  ensemble_raw_prob FLOAT64        -- raw ensemble fraction
  ensemble_calibrated_prob FLOAT64 -- model-adjusted probability
  market_yes_price FLOAT64         -- Polymarket price at snapshot
  raw_edge FLOAT64                 -- ensemble_raw_prob − market_yes_price
  calibrated_edge FLOAT64          -- ensemble_calibrated_prob − market_yes_price
  kelly_fraction FLOAT64           -- Kelly criterion bet size suggestion
  model_version STRING
  scored_at TIMESTAMP
  ```

  **Is this a new BQ table or derived?**
  - `ensemble_market_features` = BQ view (derived, no storage cost, recomputed on query).
  - `ml_opportunity_scores` = real BQ table (materialized — model output is expensive to
    recompute and needs to be queryable by the frontend without re-running inference).

  **Frontend (Product 1 extension):** The comparison UI (Product 1) can optionally surface
  `calibrated_edge` and `kelly_fraction` from this table once it exists, turning it from a
  raw data view into an actionable recommendation.

---

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

## Recently Completed (2026-03-31, session 8)

- [x] **Build `cloud-predict-analytics-market-edge` repo** ✓ 2026-03-31
  - Repo: https://github.com/FG-PolyLabs/cloud-predict-analytics-market-edge
  - Live: https://fg-polylabs.github.io/cloud-predict-analytics-market-edge/
  - Hugo static site, same Firebase Auth + ALLOWED_EMAILS as admin frontend.
  - `themes/edge/layouts/index.html` — full comparison UI:
    - City selector (hardcoded CITIES const), forecast date, Load button.
    - Fetches NBM from weather-api + Polymarket from Gamma API in parallel (Promise.all).
    - Bracket parsing: "X-Y°C/F", "above X°C/F", "below X°C/F" → NBM member count.
    - Table per target_date: Bracket | PM YES% | NBM% | Edge (±5% threshold) | Members/30.
    - Chart: date selector → grouped bar (orange = PM YES%, blue = NBM%) via Chart.js.
  - Org-level secrets/vars (Firebase + ALLOWED_EMAILS) auto-available (visibility = all repos).
  - Repo-level vars set: `HUGO_PARAMS_BACKENDURL`, `PAGES_BASE_URL`.
  - GitHub Pages enabled, `main` branch policy configured, first deploy successful.

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
