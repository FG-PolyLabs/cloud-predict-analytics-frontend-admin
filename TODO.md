# TODO — cloud-predict-analytics

Shared task list across all three repos. Update this file as work progresses.
Claude should read this at the start of each session to pick up context.

Last updated: 2026-04-03 (session 12)

---

## In Progress (session 12)

- [x] **ICON ensemble via Open-Meteo — full pipeline** ✓ 2026-04-02
  - `cmd/meteo-icon/main.go`, `internal/api/icon.go`, Cloud Run job + scheduler (4x/day at 00:05/06:05/12:05/18:05 UTC)
  - Admin page: `content/meteo-icon-forecasts/` with chart + table + distribution modal
  - Market Edge: ICON run selector, 8 new columns (Members%, Count, Temps, Edge, ROI, Fit%, Fit Edge, Fit ROI)

- [x] **NOAA NBM daily max temperature pipeline** ✓ 2026-04-03
  - Python Cloud Run job `cmd/nbm-noaa/` — fetches GRIB2 from AWS S3, extracts TMAX mean + std dev via cfgrib/xarray
  - Derives p10/p25/p50/p75/p90 from normal distribution (NBM has no raw members)
  - US-only: chicago, dallas, miami, nyc. Scheduler daily at 04:03 UTC
  - Admin page: `content/nbm-noaa-forecasts/` with chart (mean + σ + p10-p90 bands) + table
  - API: `GET /nbm-noaa-forecasts`

- [ ] **Validate NOAA NBM data landed correctly** — check 2026-04-03
  - Verify 44 rows in `nbm_noaa_forecasts` (4 cities x 11 days)
  - Compare TMAX values against NOAA NBM viewer or Weather.gov for sanity check
  - Confirm scheduler fires at 04:03 UTC and populates next day's data

- [x] **Fix UTC timezone bias in ensemble daily aggregation** ✓ 2026-04-02
  - All 3 ensemble commands (GFS, ECMWF, ICON) now load IANA timezone from tracked_cities and pass to Open-Meteo
  - Daily max now aggregated over local midnight-to-midnight, matching Polymarket/WU settlement

- [x] **Market Edge: PM snapshot time picker** ✓ 2026-04-03
  - Replaced BQ/Live radio with dropdown of distinct PM snapshot timestamps + "Live (current)"
  - New endpoint: `GET /polymarket-snapshot-times`

- [x] **Market Edge: default to edge + ROI columns only** ✓ 2026-04-02

- [x] **Tomorrow.io deterministic forecast pipeline** ✓ 2026-04-03
  - `cmd/tomorrow/main.go`, BQ table `tomorrow_forecasts`, API: `GET /tomorrow-forecasts`
  - Cloud Run job + scheduler 2x/day at 05:07, 17:07 UTC
  - 3s delay between cities to avoid 429 rate limit (free tier: 25 calls/hour)
  - API key set as env var on Cloud Run job

- [x] **Pirate Weather deterministic forecast pipeline** ✓ 2026-04-03
  - `cmd/pirate/main.go`, BQ table `pirate_weather_forecasts`, API: `GET /pirate-weather-forecasts`
  - Stores tmax_c, tmin_c, precip_prob. Cloud Run job + scheduler 2x/day at 05:13, 17:13 UTC
  - API key set as env var on Cloud Run job

- [ ] **Validate Tomorrow.io data** — check 2026-04-03 after 05:07 UTC
  - First run hit 429 rate limit; fix pushed (3s delay). Verify scheduled run succeeds.

- [x] **GEM Global + ECMWF AIFS ensemble pipelines** ✓ 2026-04-03
  - `cmd/meteo-gem` (21 members, 16-day, 12h cycles) + `cmd/meteo-aifs` (51 members, 15-day, 6h cycles)
  - Full Market Edge integration with run selectors, Edge, ROI, Fit

- [x] **NWS + Open-Meteo deterministic pipelines** ✓ 2026-04-03
  - `cmd/nws` (US-only, no API key) + `cmd/meteo-forecast` (all cities, no API key)
  - Market Edge: bracket pick columns

- [x] **Weather Underground pipeline** ✓ 2026-04-03
  - `cmd/wunderground` — fetches from api.weather.com (Polymarket settlement source)
  - Red "YES" badge in Market Edge under "Settlement" column group

- [x] **Multi-Model Ensemble (MME)** ✓ 2026-04-03
  - Computed client-side from all 10+ source predictions per target date
  - Each model's predicted high = one "member"; computes mean, σ, skewness
  - Market Edge: MME%, Edge, ROI, Fit Edge, Fit ROI columns

- [x] **Docker Hub migration** ✓ 2026-04-03
  - Switched CI from Artifact Registry to Docker Hub (philwin/cloud-predict-analytics)
  - Updated all 13 Cloud Run jobs + weather-api service to pull from Docker Hub
  - Deleted Artifact Registry `polymarket` repo
  - Deleted stale `nbm_forecasts` BQ table

- [x] **Market Edge: add deterministic sources (Tomorrow.io, Pirate Weather, NBM NOAA)**
  - Show predicted high temp per date
  - Highlight which PM bracket the prediction falls in (simple "this model picks bracket X")
  - No ensemble spread → no Members% or Fit% columns; just "Predicted High" + bracket indicator
  - NBM NOAA: can also use mean + spread for Fit%-style bracket probability (normal distribution)

- [x] **Run backfill-actuals on all newer models** ✓ 2026-04-03
  - All 8 jobs executed; actuals filled where Open-Meteo archive has data

- [x] **Open-Meteo historical backfill — best_match (free)** ✓ 2026-04-04
  - 167K rows backfilled from Jan 2024 – Apr 2026 (deterministic, all 12 cities)
  - All actuals filled from archive. Accuracy dashboard now has 2+ years of data.

- [ ] **Open-Meteo historical backfill — individual models (free, daily rate-limited)**
  - Free API supports individual model deterministic forecasts (not ensemble members)
  - Daily limit: ~10K calls/day → one model per day
  - Run in sequence, one model per day:
    - [ ] Day 1: `gfs_seamless` → backfill into `meteo_gfs_forecasts` (as deterministic predicted_max_temp_c)
    - [ ] Day 2: `ecmwf_ifs025` → backfill into `meteo_ecmwf_forecasts`
    - [ ] Day 3: `icon_seamless` → backfill into `meteo_icon_forecasts`
    - [ ] Day 4: `gem_global` → backfill into `meteo_gem_forecasts`
    - [ ] Day 5: `ecmwf_aifs025` → backfill into `meteo_aifs_forecasts`
  - **Note:** These are deterministic (single value) not ensemble (member temps). The
    backfilled rows will have predicted_max_temp_c but no member_temps array. This is still
    valuable for MAE/RMSE/bias tracking — just no bracket probability computation.
  - **Command:** `backfill-historical --model=gfs_seamless --start=2024-01-01 --end=2026-04-01`

- [ ] **Open-Meteo historical forecast "data heist" (paid — ensemble members)**
  - **Tool built:** `cmd/backfill-historical/main.go` — ready to run
  - **Requires:** Open-Meteo Professional plan (~$50-100/month, 5M calls)
  - **Plan:** Subscribe → backfill 2+ years of daily forecasts → cancel
  - **Data available:** GFS/ECMWF/ICON from Nov 2022+; AIFS from Jan 2024+
  - **Estimated calls:** ~2.6M (365 days × 12 cities × 6 models × ~10 forecast days / batch)
  - **Command:** `backfill-historical --all-models --start=2024-01-01 --end=2026-04-01`
  - **Also backfill actuals** after historical forecasts are loaded (free archive API)
  - **Value:** Instant ML training dataset instead of waiting months to accumulate
  - GEM, AIFS, NWS, Open-Meteo det, WU, NBM NOAA all have missing actuals for past target dates
  - Trigger each job manually or wait for scheduled runs (all include --backfill-actuals)

- [x] **ML comparison view — design sketched, deferred** ✓ 2026-04-03

---

## ML & Prediction Pipeline Roadmap

### Phase 1: Data Foundation (now — build as backfill runs)

- [ ] **1.1 BQ model comparison view**
  - Union view across all 11+ forecast tables: one row per (city, target_date, source)
  - Columns: source, predicted_high_c, actual_high_c, error_c, abs_error_c, lead_days, model_run_at
  - Enables instant queries: `SELECT source, AVG(ABS(error_c)) as MAE GROUP BY source`
  - Build as a `CREATE VIEW weather.model_comparison AS ...`

- [ ] **1.2 Backfill actuals for historical data**
  - After historical backfill completes (~167K rows from Open-Meteo best_match 2024-2026):
    run backfill-actuals to fill `actual_max_temp_c` + `error_c` for all past target dates
  - Open-Meteo archive API (free) covers observed temps back to 1940
  - This gives instant accuracy metrics: MAE/RMSE/bias per city per lead_days

- [ ] **1.3 Polymarket resolution outcome tracking**
  - BQ view `market_outcomes`: for each resolved market (target_date < today):
    - actual_temp (from WU or Open-Meteo archive)
    - winning_bracket (which PM bracket the actual fell in)
    - PM yes_cost at various timestamps (what the market priced it at)
    - each model's prediction at the time
    - hypothetical P&L: if you bet on the model's edge signal, did you profit?
  - Enables: "which model would have made the most money on Polymarket?"

### Phase 2: Accuracy Dashboard (after Phase 1 + ≥30 resolved dates)

- [ ] **2.1 Model accuracy admin page** — `/model-accuracy/`
  - **Scoreboard table:** MAE, RMSE, mean bias per model, sortable. Highlight best/worst.
  - **Accuracy by lead_days chart:** line chart showing error growth as forecast horizon increases.
    Each model is a line. Reveals which models hold accuracy longest.
  - **City breakdown:** heatmap or table showing MAE per (model × city). Some models may excel
    in certain climates (GEM for Toronto, AIFS for tropical cities, etc.)
  - **Error distribution:** box plot per model showing spread of errors (outliers, skew)
  - **Head-to-head:** scatter plot of Model A error vs Model B error, colored by city.
    Points above the diagonal = Model A was worse.
  - **Filterable** by date range, city, lead_days

- [ ] **2.2 Polymarket P&L simulator + backtesting** — `/pm-simulator/`
  - **Core P&L view:** For each resolved market, show what happened if you followed edge signals
    - Columns: date, city, bracket, PM YES%, model prob, edge, bet side (YES/NO), outcome (win/lose), P&L
    - Summary row: total return, win rate, avg edge, max drawdown per model
    - Filterable by model, city, min edge threshold
  - **Backtesting strategies (after historical backfill):**
    - [x] **Strategy 1: Fade Market (NO bets)** ✓ 2026-04-04
      - Bet NO when all deterministic models disagree AND majority of ensemble models
        show probability at least Xpp below PM price
      - Hold to expiration
    - [ ] **Strategy 1b: Fade Market with exit** — same entry as Strategy 1 but with exit logic:
      - Fixed exit: sell NO position when price reaches target (e.g. buy at $0.90, sell at $0.95)
      - Percentage gain: sell when profit hits X% (e.g. 25% gain on $0.90 = sell at $0.925+)
      - Requires intraday PM price history to simulate (polymarket_snapshots timestamps)
    - [ ] **Strategy 2: Single-model edge** — bet whenever one model shows >X% edge
      - Configurable threshold slider (5%, 10%, 15%, 20%)
      - Show cumulative P&L curve over time per model
      - Reveals: which model generates the most profitable signals?
    - [ ] **Strategy 2: Multi-model consensus** — bet only when N+ models agree
      - "At least 3 of 5 ensemble models show >10% edge on the same bracket"
      - Higher conviction = fewer trades but better win rate
      - Configurable: min models agreeing, min edge threshold
    - [ ] **Strategy 3: Model-weighted edge** — weight each model's probability by historical accuracy
      - Uses BMA weights from Phase 3 when available
      - Until then, use equal weights (MME)
      - Bet when weighted consensus shows >X% edge
    - [ ] **Strategy 4: Fade the settlement source** — bet against WU when ensemble models disagree
      - WU prediction lands in bracket X, but ensemble models say bracket Y is more likely
      - High risk/high reward: betting that WU's own forecast is wrong
    - [ ] **Strategy 5: Lead-day optimized** — only bet at optimal lead times
      - Some models are more accurate at 1-day lead vs 5-day lead
      - Filter trades to only take signals at lead times where the model historically performs best
  - **Backtesting metrics per strategy:**
    - Total P&L ($), ROI (%), win rate, avg profit per trade, avg loss per trade
    - Max drawdown, Sharpe-like ratio (avg return / std dev of returns)
    - Profit factor (gross profits / gross losses)
    - Trade count (enough trades to be statistically meaningful?)
  - **Backtesting chart:** cumulative P&L over time, one line per strategy
  - **Data requirements:**
    - Resolved markets with actual outcomes (actual_max_temp_c backfilled)
    - PM prices at the time of the forecast (polymarket_snapshots.yes_cost)
    - Model predictions at the time (forecast tables with model_run_at)
    - For full backtesting: historical backfill data (Open-Meteo free + paid)
  - **Implementation:**
    - BQ view `backtesting_trades`: joins forecasts + PM prices + actuals for each resolved date
    - API endpoint: `GET /backtesting?strategy=consensus&min_edge=10&min_models=3&city=dallas`
    - Frontend: strategy selector, parameter sliders, cumulative P&L chart, trade log table

### Phase 3: ML Model Training (after ≥60 days of multi-source data OR after historical backfill)

- [ ] **3.1 Feature engineering pipeline**
  - Input features per (city, target_date, bracket):
    - Each model's bracket probability (ensemble Members%, Fit%, deterministic binary)
    - Model agreement score (how many models agree on this bracket)
    - Ensemble spread metrics (avg σ across models, max σ, min σ)
    - Lead days
    - City/region encoding
    - Seasonal features (month, day of year)
    - PM price (yes_cost) at prediction time
    - Historical model accuracy for this city + lead_days (rolling 30-day MAE)
  - Output label: did the actual temp fall in this bracket? (binary 0/1)
  - Store as BQ view `ml_training_features`

- [ ] **3.2 Calibrated probability model**
  - **Method 1: Bayesian Model Averaging (BMA)**
    - Weight each model's probability by its historical accuracy
    - Weights update as more data arrives
    - Simple, interpretable, no training infrastructure needed
    - Can run as a BQ SQL query or Python notebook
  - **Method 2: Gradient Boosted Trees (XGBoost/LightGBM)**
    - Train on features from 3.1 → predict bracket probability
    - Cross-validate with time-series split (train on past, predict future)
    - More powerful but needs periodic retraining
    - Run as a Python script or Vertex AI job
  - **Method 3: Quantile Regression**
    - Instead of point probability, predict the full temp distribution
    - Input: all model predictions. Output: calibrated percentiles (p10–p90)
    - Natural fit for bracket probability computation
  - **Recommendation:** Start with Method 1 (BMA) — it works immediately with SQL.
    Graduate to Method 2 when you have enough data and want to capture nonlinear interactions.

- [ ] **3.3 "Best Estimate" column in Market Edge**
  - New column group showing the ML-calibrated bracket probability
  - Edge and ROI computed against this calibrated estimate
  - Updated daily as the model retrains on new actuals
  - This becomes the "house view" — the system's best guess combining all sources

- [ ] **3.4 Model retraining pipeline**
  - Python script: queries BQ for features + actuals → trains model → saves weights
  - Run weekly (cron on homeserver or Cloud Run job)
  - Output: model weights stored in GCS or BQ `model_weights` table
  - Market Edge loads latest weights on page load
  - Monitor for accuracy degradation (alert if rolling MAE increases)

### Phase 4: Advanced (long-term)

- [ ] **4.1 Real-time edge alerts**
  - When a model finds significant edge (>10%) against PM prices, send a notification
  - Channels: Slack webhook, email, or push notification
  - Configurable thresholds per model confidence level

- [ ] **4.2 Live backtesting dashboard**
  - Real-time view of how each strategy would be performing today
  - "Strategy X is currently 3-for-5 this week with +12% ROI"
  - Auto-updates as markets resolve each day

- [ ] **4.3 Ensemble of ensembles**
  - Train an ML model that takes raw member temps from ALL ensemble models (GFS 30 + ECMWF 51
    + ICON 40 + GEM 21 + AIFS 51 = 193 members) and produces a unified distribution
  - This is more sophisticated than MME (which just uses means) — it uses the full shape
    of each model's distribution
  - Requires historical ensemble member data (Open-Meteo Professional backfill)

- [ ] **4.4 Temporal patterns**
  - Track how model accuracy changes throughout the day (which model run time is best?)
  - Track seasonal accuracy patterns (models may be better in summer vs winter)
  - Use these patterns to dynamically weight models by time-of-day and season

---

## In Progress (session 11)

- [x] **Investigate Cloud Scheduler PERMISSION_DENIED failures** ✓ 2026-04-02
  - Root cause: `polymarket-runner` SA was missing `roles/run.invoker`.
  - Fix: granted `roles/run.invoker` at project level via `gcloud projects add-iam-policy-binding`.

- [x] **Decide and configure job run frequency** ✓ 2026-04-02
  - GFS: 4x/day — `0 3,9,15,21 * * *` (aligns with GFS model cycles)
  - ECMWF: 2x/day — `0 4,16 * * *` (aligns with ECMWF 00z/12z cycles)
  - Polymarket: 4x/day — `0 1,7,13,19 * * *`
  - Sync: 1x/day — `0 5 * * *` (after first GFS + ECMWF runs land)

---

## In Progress (session 10)

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

### Infrastructure / Cost Reduction

- [ ] **[Infra] Migrate container images from Artifact Registry to Docker Hub (public)**
  - Artifact Registry charges $0.10/GB/month storage. For a project with several Cloud Run jobs
    (weather-api, weather-nbm, weather-ecmwf, weather-polymarket, weather-sync) this adds up.
  - **Target: Docker Hub public repos** — free for unlimited public images; Cloud Run can pull
    public Docker Hub images natively with no extra auth or credential configuration needed.
    GHCR is also free for public repos but requires additional Cloud Run credential setup for
    private images — Docker Hub public avoids that concern entirely.
  - **Changes needed (all in `cloud-predict-analytics` repo):**
    1. Create a Docker Hub account/org (e.g. `fgpolylabs`) and create public repos for each image
    2. Add `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` as GitHub org secrets
    3. `.github/workflows/build.yml` — replace the `gcloud auth` + Artifact Registry push steps with:
       ```yaml
       - uses: docker/login-action@v3
         with:
           username: ${{ secrets.DOCKERHUB_USERNAME }}
           password: ${{ secrets.DOCKERHUB_TOKEN }}
       - run: docker build -t fgpolylabs/weather-api:latest . && docker push fgpolylabs/weather-api:latest
       ```
    4. Update all `gcloud run deploy` steps to reference `docker.io/fgpolylabs/weather-api:latest`
    5. After confirming deploys work, delete the Artifact Registry repository in GCP console
  - One-time migration; no ongoing code changes after the workflow is updated

- [ ] **[Infra] Homeserver-first scheduled jobs with Cloud Run as fallback**
  - **Goal:** Run weather ingest jobs (weather-nbm, weather-ecmwf, weather-polymarket, weather-sync,
    and future jobs) on a self-hosted Proxmox node as the primary runner. Cloud Run runs slightly
    later as a watchdog — if the homeserver job already succeeded, Cloud Run exits immediately
    (minimal cost: a single BQ query). If the homeserver was down or failed, Cloud Run runs the
    full job.
  - **Heartbeat pattern:**
    1. Homeserver job runs at the scheduled time (e.g., weather-polymarket at 01:00 UTC)
    2. On successful completion, job writes a record to a new BQ table `job_heartbeats`:
       `job_name STRING, run_at TIMESTAMP, status STRING ('success'|'failed'), rows_written INT64,
       runner STRING ('homeserver'|'cloud-run')`
    3. Cloud Run job runs 30 minutes later (e.g., 01:30 UTC)
    4. Cloud Run job queries `job_heartbeats` first: if a `success` record exists for this
       `job_name` where `run_at > TIMESTAMP_SUB(NOW(), INTERVAL 2 HOUR)`, exit 0 — done.
    5. If no recent success found: run the full job, write a heartbeat with `runner='cloud-run'`
  - **Homeserver setup:**
    - Run the same Go binaries (or Docker containers using the same image) via systemd timers
      or cron inside a Proxmox LXC container
    - Binaries need GCP credentials: use a service account JSON key or Workload Identity
      Federation via OIDC (preferred — no long-lived keys). Store credentials in the LXC.
    - Same env vars as Cloud Run (`BQ_PROJECT`, `BQ_DATASET`, etc.) set in the systemd unit file
    - Schedule homeserver jobs 30 minutes before the Cloud Run schedule as the primary window
  - **Cloud Run changes:** Add a `--check-heartbeat` flag (or auto-detect via env var
    `HEARTBEAT_CHECK=true`) to each job's `main.go` that performs the BQ check before doing any work
  - **Cost impact:** Cloud Run jobs that exit after a BQ query (~1–2 seconds) cost essentially
    nothing. Normal Cloud Run costs only incur when the homeserver is down.
  - **Failure alerting:** if `runner='cloud-run'` appears in `job_heartbeats` on a day when
    it should have been `runner='homeserver'`, surface a warning in the admin UI health check

- [ ] **[Infra] Homelab-primary API via nginx reverse proxy + manual Cloud Run fallback**
  - **Goal:** Route `weather-api` traffic to a self-hosted Go binary on the homelab as primary.
    Cloud Run remains deployed but idle (scales to zero). If homelab goes down, manually update
    DNS to point at Cloud Run until homelab is restored.
  - **Why not automatic failover:** any failover mechanism that runs on the homelab (nginx,
    Cloudflare Tunnel, etc.) goes down with the homelab — automatic failover requires an external
    component (e.g. Cloudflare Workers). Manual DNS failover is simpler and sufficient for this
    project's availability requirements.
  - **Architecture:**
    ```
    api.yourdomain.com (Cloudflare DNS, proxied)
      └─ points to homelab IP (nginx on Proxmox)
           └─ nginx reverse proxy → weather-api Go binary on :8080

    Manual fallback: update Cloudflare DNS A record to Cloud Run IP (or CNAME to Cloud Run URL)
    ```
  - **Homelab setup (Proxmox LXC):**
    1. Build or pull the `weather-api` binary (same Docker image or compile from source)
    2. Run as a systemd service on port 8080 inside an LXC container
    3. Same env vars as Cloud Run — store in `/etc/weather-api.env`, loaded by the systemd unit
    4. GCP credentials: create a service account key JSON, store securely on the LXC
       (or use Workload Identity Federation if preferred — no long-lived keys)
    5. nginx config: standard `proxy_pass http://localhost:8080`, SSL termination via
       Let's Encrypt (certbot) or Cloudflare's edge TLS (origin cert)
  - **nginx config sketch:**
    ```nginx
    server {
        listen 443 ssl;
        server_name api.yourdomain.com;
        # SSL: either Let's Encrypt cert or Cloudflare origin cert
        location / {
            proxy_pass http://127.0.0.1:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
    ```
  - **Manual failover procedure (if homelab goes down):**
    1. Log in to Cloudflare dashboard
    2. Update the `api.yourdomain.com` A/CNAME record to point at the Cloud Run service URL
    3. Cloud Run scales up automatically on first request
    4. When homelab is restored, revert the DNS record
  - **Cost impact:** Cloud Run `weather-api` scales to zero when homelab is healthy — zero cost
    during normal operation. Cloud Run costs only incur during homelab downtime.
  - **Firebase Auth:** validation happens inside the Go binary regardless of where it runs —
    no changes to auth flow needed

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

- [x] **[Models] ICON ensemble via Open-Meteo — new BQ table + admin dashboard** ✓ 2026-04-02
  - Model: `icon_seamless` (DWD, ~13 km, 40 members, strong in Europe)
  - `cmd/meteo-icon/`, BQ table `meteo_icon_forecasts`, Cloud Run job + scheduler 4x/day
  - Admin page + Market Edge integration complete

- [x] **[Models] Real NOAA NBM data — new BQ table + admin dashboard** ✓ 2026-04-03
  - Python Cloud Run job `cmd/nbm-noaa/`, BQ table `nbm_noaa_forecasts`
  - GRIB2 from AWS S3, TMAX mean + std dev, derived percentiles
  - US-only: chicago, dallas, miami, nyc. Scheduler daily at 04:03 UTC

- [ ] **[Models] Real NOAA NBM data — Market Edge integration**
  - NBM has no raw members — show as "fit-only" source using mean + std dev for normal distribution bracket probabilities
  - Add NBM columns to Market Edge (Fit%, Fit Edge, Fit ROI) for US cities only

- [ ] **[Models] Real NOAA NBM data — admin page improvements**
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

- [ ] **[Models] Tomorrow.io — point-estimate daily high ingest** ⚠️ LOW PRIORITY
  - **What they provide:** deterministic daily `temperatureMax` point estimate only on free tier.
    Probabilistic endpoint (p5/p10/p25/p50/p75/p90/p95) is confirmed paid-only and hourly-only
    (not daily); deriving daily high distribution from hourly percentiles is an approximation
    and not worth the cost at this stage.
  - **Prerequisite before building:** sign up for free API key, make one test call with
    `timesteps=1d` and verify: (a) `temperatureMax` is in the daily response, (b) it represents
    the true daily high (not a midday spot temp or average). Until verified, schema is TBD.
  - **Market-edge role:** point-estimate column only — shows predicted high + fetch time alongside
    ensemble-based sources. No Members%, no σ/skew, no edge calculation for this source.
  - Free tier: 500 calls/day, 25/hour — adequate for 12 cities once verified
  - BQ table: `tomorrow_forecasts`
  - Schema (pending verification): city, target_date, forecast_date, lead_days, tmax_c,
    fetched_at, actual_max_temp_c, error_c
  - Backend: new Cloud Run job `weather-tomorrow` (`cmd/tomorrow/main.go`)
  - Admin page: `content/tomorrow-forecasts/`
  - API key: store in Secret Manager as `TOMORROW_API_KEY`

- [ ] **[Models] Pirate Weather — point-estimate daily high ingest** ⚠️ LOW PRIORITY
  - **What they provide:** deterministic daily high only. Uses GEFS 30-member ensemble internally
    but exposes no spread, σ, percentiles, or member arrays for temperature. The only uncertainty
    field in the API is `precipIntensityError` (precipitation only — useless for our use case).
  - **Market-edge role:** point-estimate column only — shows predicted high (`temperatureHigh`)
    + the time that prediction was fetched. No Members%, no σ/skew, no edge calculation.
  - API: `GET https://api.pirateweather.net/forecast/{key}/{lat},{lon}?exclude=currently,minutely,hourly,alerts`
  - Daily fields to store: `temperatureHigh` (daytime high 6am–6pm, in °F — convert to °C at ingest),
    `temperatureHighTime`, `temperatureLow`, `precipProbability`, `icon`
  - Note: `temperatureHigh` (daytime high) is more relevant than `temperatureMax` (true 24h max)
    for Polymarket markets which resolve on the daytime high
  - Free tier: 20,000 calls/month — adequate for 12 cities daily with headroom
  - BQ table: `pirate_weather_forecasts`
  - Schema: city, target_date, forecast_date, lead_days, tmax_c, tmax_time, tmin_c,
    precip_prob, icon, fetched_at, actual_max_temp_c, error_c
  - Backend: new Cloud Run job `weather-pirate` (`cmd/pirate/main.go`)
  - Admin page: `content/pirate-weather-forecasts/`
  - API key: store in Secret Manager as `PIRATE_WEATHER_API_KEY`
  - Note: Dark Sky-compatible response shape

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

### AI / Self-Hosted Weather Models

- [ ] **[Models] ECMWF AIFS ensemble via Open-Meteo — new BQ table + admin dashboard** ⭐ HIGH PRIORITY
  - ECMWF's own AI Forecasting System is already available through Open-Meteo's ensemble API —
    same interface as existing GFS and ECMWF IFS integrations, trivially easy to add.
  - Model: `ecmwf_aifs025` (AIFS = Artificial Intelligence Forecasting System)
    - 51 ensemble members, 0.25° global resolution, 6-hourly, 15-day forecast
    - Updated every 6 hours via Open-Meteo
    - Neural network model trained by ECMWF — state-of-the-art AI NWP
  - Implementation: copy `cmd/ecmwf/main.go`, change model param to `ecmwf_aifs025`, new BQ table
  - BQ table: `aifs_forecasts` — identical schema to `ecmwf_forecasts`
    (city, target_date, forecast_date, lead_days, member_count, member_temps[], model, fetched_at,
    actual_max_temp_c, error_c)
  - Admin page: `content/aifs-forecasts/` — identical layout to ECMWF page
  - Market-edge: full ensemble source — Members%, Raw Edge, ROI, Fit%, Fit Edge, Fit ROI
  - No new API key needed — same Open-Meteo free tier as existing jobs
  - **This is the easiest high-value add in the backlog — almost zero new code**

- [ ] **[Models] GenCast ensemble on Proxmox homeserver**
  - **What:** Run Google DeepMind's GenCast (diffusion-based probabilistic weather model) on a
    self-hosted Proxmox VM with GPU passthrough. Produces true ensemble members via diffusion
    sampling — each run generates a different plausible forecast.
  - **Hardware requirements:**
    - GPU: NVIDIA with ≥16GB VRAM (RTX 3090/4090, A4000, or similar). GenCast 1° mini runs on
      a T4 (16GB) in Colab; the 0.25° full model needs ≥40GB (A100).
    - RAM: ≥32GB system memory for loading initial conditions + model weights
    - Storage: ~50GB for model weights + daily GFS analysis files (~2GB/run)
  - **Software stack (Proxmox VM or LXC container):**
    - Ubuntu 22.04 LTS VM with NVIDIA GPU passthrough
    - Docker with nvidia-container-toolkit
    - Container: `python:3.11` + JAX (GPU) + GenCast weights + google-cloud-bigquery
    - Cron job: runs 2x/day after GFS 00z and 12z analysis become available (~4h delay)
  - **Pipeline:**
    1. Download latest GFS 0.25° analysis from NOMADS (initial conditions)
       `https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.YYYYMMDD/HH/atmos/gfs.tHHz.pgrb2.0p25.f000`
    2. Preprocess: regrid to GenCast input format (ERA5-like pressure levels)
    3. Run GenCast inference: N=30 samples → 30 ensemble members (each is a full 15-day global forecast)
    4. Extract 2m temperature (T2M) for all 12 city coordinates
    5. Compute daily max temp per member per city per target date
    6. Write to BQ `gencast_forecasts` table (same schema as meteo_gfs_forecasts: member_temps[], stats)
    7. Push results to BQ via service account key stored on the homeserver
  - **BQ table:** `gencast_forecasts` — same schema as ensemble models
  - **API:** `GET /gencast-forecasts`
  - **Market Edge:** full ensemble treatment (Members%, Edge, ROI, Fit%)
  - **Resolution tradeoff:** 1° mini (~110km) is coarser than operational models but GenCast's
    AI approach may still add independent signal. Full 0.25° requires A100-class GPU.
  - **Implementation steps:**
    1. Set up Proxmox VM with GPU passthrough + Docker + nvidia-toolkit
    2. Build Docker image with GenCast + dependencies (JAX GPU + model weights)
    3. Write Python script: download GFS analysis → run GenCast → extract cities → write BQ
    4. Test end-to-end with a single date
    5. Set up cron schedule + monitoring
    6. Add API endpoint + Market Edge integration
  - **License:** CC BY-NC-SA — non-commercial only; fine for personal research/prediction

- [ ] **[ML] Statistical post-processing / model weighting**
  - After accumulating ≥30 days of actual vs forecast data, train a calibration model:
    - Input: all 11 source predictions + lead_days + city
    - Output: calibrated probability distribution (optimal weights per source)
    - Methods: quantile regression, gradient boosting (XGBoost/LightGBM), or Bayesian model averaging
  - Store calibration weights in BQ `model_calibration` table
  - Use calibrated probabilities in Market Edge as a "Best Estimate" column
  - Re-train weekly as more actuals accumulate
  - **Prerequisite:** ≥30 days of multi-source forecast data with actuals backfilled

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
    - *Ensemble source* (Open-Meteo GFS, ECMWF IFS, ECMWF AIFS, ICON, GenCast if built): show
      Members%, Members count, Raw Edge, ROI, Fit%, Fit Edge, Fit ROI — current full layout.
    - *Deterministic source* (Pirate Weather, OWM): these sources show a "Predicted High" column
      only (the point estimate + fetch time). No Members%, no edge/ROI columns. They serve as a
      reference data point alongside the ensemble sources, not as a betting signal themselves.
    - *Tomorrow.io*: same as deterministic until/unless paid probabilistic tier is verified.
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

## Recently Completed (2026-04-01, session 10)

- [x] **Local MCP server for BigQuery queries** ✓ 2026-04-01
  - `mcp/bq_server.py` — Python MCP server using `mcp[cli]` + `google-cloud-bigquery`.
  - Tools: `list_tables`, `get_schema(table_name)`, `query(sql, max_rows)`.
  - Read-only: DML (INSERT/UPDATE/DELETE/etc.) is blocked; 50 MB per-query billing cap.
  - Auth: Application Default Credentials (`gcloud auth application-default login`).
  - Registered in `.claude/settings.json` — auto-starts with every Claude Code session in this repo.
  - Install deps once: `pip install -r mcp/requirements.txt`.

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
