# TODO — cloud-predict-analytics

Shared task list across all three repos. Update this file as work progresses.
Claude should read this at the start of each session to pick up context.

Last updated: 2026-03-31 (session 7, paused mid-build of market-edge repo)

---

## Next Up

- [ ] **[IN PROGRESS] Build `cloud-predict-analytics-market-edge` repo** — resume session 7
  - Repo path: `../cloud-predict-analytics-market-edge/` (sibling dir, not yet git-init'd)
  - Repo name: `cloud-predict-analytics-market-edge`
  - Purpose: auth-gated (Firebase + ALLOWED_EMAILS) NBM vs Polymarket comparison UI.
    Pick a city → fetch NBM from weather-api + Polymarket markets from Gamma API → show
    bracket-by-bracket comparison table (YES%, NBM%, edge) + grouped bar chart.
  - **Files already created** (scaffold is done):
    - `hugo.toml`, `.env.example`, `.gitignore`
    - `.github/workflows/deploy.yml`
    - `content/_index.md`
    - `static/css/app.css`, `static/js/firebase-init.js`, `static/js/api.js`, `static/js/app.js`
    - `themes/edge/layouts/_default/baseof.html`
    - `themes/edge/layouts/partials/head.html`, `navbar.html`, `footer.html`, `scripts.html`
  - **Still needed** (pick up here):
    1. `themes/edge/layouts/index.html` — the main comparison page (most of the work):
       - Auth guard + sign-in prompt
       - Controls: city selector (hardcoded CITIES list), forecast date input, Load button
       - Fetches NBM: `api('GET', '/nbm-forecasts' + qs({ city, forecast_date }))`
       - Fetches Polymarket per target_date: `GET https://gamma-api.polymarket.com/events?slug={slug}`
         Slug format: `highest-temperature-in-{city}-on-{month}-{day}-{year}` (e.g. `highest-temperature-in-miami-on-april-4-2026`)
         Current YES price: `market.outcomePrices[0]` (string "0.75" → multiply × 100 for %)
       - Bracket parsing (JS): handle "X-Y°C", "X-Y°F" (convert to °C), "above X°C/F", "below X°C/F"
         For "above X°C": NBM prob = members >= X / total
         For "X-Y°C": NBM prob = members in [lo, hi) / total
       - Table per target_date: Bracket | Polymarket YES% | NBM% | Edge | Members/30
         Edge color: green (>+5%) = YES value, red (<-5%) = NO value, gray = neutral
       - Chart: date selector → grouped bar chart (Chart.js), brackets on X-axis,
         Polymarket YES% (orange) and NBM% (blue) as two bar series
       - Dates with no Polymarket market: show NBM row with "No market" in Polymarket column
    2. `CLAUDE.md` for the new repo (project instructions)
    3. `git init` + initial commit + push to new GitHub repo `FG-PolyLabs/cloud-predict-analytics-market-edge`
    4. Set up GitHub Pages + repo secrets/vars (same Firebase project as admin, same ALLOWED_EMAILS)
  - **Key design notes from code review:**
    - `extractTempThreshold` in Go takes upper bound of "X-Y°C" ranges (e.g. "24-25°C" → 25.0)
    - Gamma API is CORS-enabled (public); if CORS fails in practice, add proxy endpoint to weather-api
    - `OutcomePrices` field on GammaMarket = `["0.75", "0.25"]` (YES, NO as decimal strings)
    - City slugs used in Polymarket match BQ city slugs directly ("nyc", "buenos-aires", etc.)
    - Fetch all dates in parallel with `Promise.all` for speed

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

### Product 1 — NBM vs Polymarket comparison UI

**Goal:** A decision-support tool. Pick a city, see the NBM ensemble probability per temperature bracket side-by-side with Polymarket's YES/NO prices for that bracket — so you can spot mispricing and decide whether to bet.

- [ ] **[Product 1] NBM × Polymarket comparison page (admin tab first, standalone app later)**

  **UX flow:**
  1. User selects a city (e.g. Miami).
  2. Clicks "Load" — fetches today's NBM ensemble forecast + all open Polymarket markets for that city.
  3. Page renders one row per (target_date × temperature bracket):
     - **NBM empirical probability** — `member_count_in_bracket / 30` (e.g. 3/30 = 10%)
     - **NBM std dev and skewness** — from stored `temp_std_dev_c` / `skewness`
     - **Polymarket YES price** (implied probability of that bracket resolving YES)
     - **Polymarket NO price** (= 1 − YES price roughly)
     - **Edge** — difference between NBM probability and Polymarket YES price (positive = model says more likely than market implies)
  4. Table sortable by edge; chart option: grouped bars per target_date (NBM% vs Polymarket YES%).

  **Data sourcing:**
  - Access-controlled: restricted to authorized emails via Firebase Auth (same whitelist as
    admin site). Not public — no GCS/GitHub export needed.
  - NBM data: fetched from `weather-api /nbm-forecasts` with Firebase ID token (same `api()`
    helper pattern as admin). No new public endpoint or GCS export required.
  - Polymarket data: Polymarket exposes a public REST API — fetch directly from browser JS,
    no backend proxy needed.
  - **Decision:** both admin tab and future standalone app hit `weather-api` directly with auth.
    Standalone app = new repo (e.g. `cloud-predict-analytics-frontend`) with its own Firebase
    Auth setup but same `ALLOWED_EMAILS` whitelist and same API.

  **Bracket alignment:**
  - Polymarket markets are defined per temperature bracket (e.g. "Will Miami high be 24–25°F?").
    Need to map market bracket → matching NBM 1°C bins and sum their probabilities.
  - Bracket definitions vary by market; need to parse them from market titles (the
    `extractTempThreshold` logic already exists in `weather-polymarket` job).

  **Admin tab:** Add as a new content section `content/nbm-vs-market/_index.md` + layout.
  Standalone app: new repo under FutureGadgetLabs when ready to productionize.

---

### Product 2 — ML opportunity detection (analytics backend)

**Goal:** Given a snapshot of today's NBM forecast and Polymarket prices, predict whether there is a positive-edge betting opportunity based on how well the model has been calibrated historically.

- [ ] **[Product 2, data] Add `realized_highs` BQ table**

  Standalone source-of-truth for observed daily max temperatures.
  - Schema: `city STRING, date DATE, actual_max_temp_c FLOAT64, source STRING` (e.g. "open-meteo-archive")
  - Populated by a new `--backfill-realized` mode (or repurpose `--backfill-actuals`) in `cmd/nbm/main.go`.
  - Note: `nbm_forecasts.actual_max_temp_c` stores the same data but denormalized across
    all forecast_date rows per (city, target_date). `realized_highs` is the deduplicated
    canonical record — one row per (city, date).
  - `weather-sync` should export this table to GCS + GitHub alongside existing exports.

- [ ] **[Product 2, data] Add `nbm_market_features` BQ view (feature engineering layer)**

  A BQ view (not a table — derived on-demand) joining:
  - `nbm_forecasts` — ensemble stats + member_temps per (city, target_date, forecast_date)
  - `polymarket_snapshots` — YES/NO prices per (city, target_date, bracket, snapshot_time)
  - `realized_highs` — actual outcome per (city, target_date)

  Key derived columns:
  - `nbm_bracket_prob` — fraction of members falling within the Polymarket bracket
  - `market_yes_price` — Polymarket implied YES probability at snapshot time
  - `edge` — `nbm_bracket_prob − market_yes_price`
  - `resolved_yes` — 1 if actual high fell within bracket, 0 otherwise (nullable until resolved)
  - `lead_days` — days from forecast_date to target_date (model accuracy degrades with lead)

  This view is the training dataset for all ML models.

- [ ] **[Product 2, ML] Build calibration model and `ml_opportunity_scores` BQ table**

  **What the model predicts:** Given (city, target_date, bracket, snapshot_date), is the NBM
  ensemble's probability well-calibrated vs. the Polymarket price? If NBM says 30% and the
  market says 15%, is that a real edge or is the NBM model systematically overconfident at
  this lead time / city / temperature range?

  **Architecture:**
  - Python Cloud Run job (`cmd/ml` or `scripts/ml_score.py`) — runs on demand or daily.
  - Reads `nbm_market_features` from BQ as training/inference data.
  - Model: start simple — logistic regression or isotonic regression to calibrate NBM
    probabilities against historical `resolved_yes` outcomes, grouped by lead_days bucket.
  - Outputs written to new BQ table `ml_opportunity_scores`:

  ```
  city STRING
  target_date DATE
  bracket STRING               -- e.g. "24–25°C"
  snapshot_date DATE
  nbm_raw_prob FLOAT64         -- raw ensemble fraction
  nbm_calibrated_prob FLOAT64  -- model-adjusted probability
  market_yes_price FLOAT64     -- Polymarket price at snapshot
  raw_edge FLOAT64             -- nbm_raw_prob − market_yes_price
  calibrated_edge FLOAT64      -- nbm_calibrated_prob − market_yes_price
  kelly_fraction FLOAT64       -- Kelly criterion bet size suggestion
  model_version STRING
  scored_at TIMESTAMP
  ```

  **Is this a new BQ table or derived?**
  - `nbm_market_features` = BQ view (derived, no storage cost, recomputed on query).
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
