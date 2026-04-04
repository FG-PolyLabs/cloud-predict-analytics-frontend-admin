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

- [ ] **Run backfill-actuals on all newer models** — 2026-04-04
  - GEM, AIFS, NWS, Open-Meteo det, WU, NBM NOAA all have missing actuals for past target dates
  - Trigger each job manually or wait for scheduled runs (all include --backfill-actuals)

- [ ] **Create BQ model accuracy comparison view**
  - Union view across all 11 forecast tables: one row per (city, target_date, source)
  - Columns: source, predicted_high, actual_high, error, abs_error, lead_days
  - Enables: `SELECT source, AVG(ABS(error)) as MAE GROUP BY source`
  - Prerequisite for ML training and accuracy dashboard

- [ ] **Create model accuracy dashboard (admin frontend)**
  - New page: `/model-accuracy/`
  - Table: MAE, RMSE, bias per model per city, filterable by lead_days
  - Chart: error distribution per model (box plot or histogram)
  - Chart: accuracy by lead_days (does error grow with longer forecasts?)
  - **Needs ≥30 resolved target dates** for meaningful stats (~2-4 weeks from now, ~Apr 20+)

- [ ] **Track Polymarket resolution outcomes**
  - After a market resolves, record which bracket won (actual high from WU)
  - Compare against each model's prediction at the time
  - Compute: did the model's edge signal produce a profitable trade?
  - BQ table or view: `market_outcomes` — city, date, winning_bracket, actual_temp,
    model predictions at the time, PM prices at the time, hypothetical P&L per model

- [x] **ML comparison view — design sketched, deferred** ✓ 2026-04-03
  - Union view across all models → one row per (city, target_date, model)
  - Bracket-level training view for PM edge evaluation
  - Build after all forecast sources are integrated

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
