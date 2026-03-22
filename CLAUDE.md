# cloud-predict-analytics-frontend-admin

## Multi-Repo Project: cloud-predict-analytics

This repo is **one of three** repositories that together form the cloud-predict-analytics system. When working on this project, all three repos should be cloned as siblings under the same parent directory.

### Repository Layout

```
FutureGadgetLabs/
├── cloud-predict-analytics-frontend-admin/   ← THIS REPO (admin frontend)
├── cloud-predict-analytics/                  ← backend (API + scheduled jobs)
└── cloud-predict-analytics-data/             ← data repo + public frontend
```

### Repository Roles

| Repo | GitHub | Role |
|------|--------|------|
| `cloud-predict-analytics-frontend-admin` | https://github.com/FG-PolyLabs/cloud-predict-analytics-frontend-admin | Admin-only UI; authenticated CRUD via backend API; reads JSON from data repo or GCS |
| `cloud-predict-analytics` | https://github.com/FG-PolyLabs/cloud-predict-analytics | Two parts: (1) Cloud Run API service (`weather-api`) for all mutations; (2) Cloud Run scheduled job (`weather-polymarket`) that fetches/updates data on a daily schedule |
| `cloud-predict-analytics-data` | https://github.com/FG-PolyLabs/cloud-predict-analytics-data | JSON data files updated by the backend; also hosts the public (non-admin) frontend |

### First-Time Setup

Run the setup script to clone all sibling repos:

```bash
bash scripts/setup.sh
```

---

## This Repo: Admin Frontend

### Architecture

- **Framework:** [Hugo](https://gohugo.io/) — static site generator with Go templates
- **Theme:** Custom theme (`themes/admin/`) — minimal Bootstrap 5 layout
- **Auth:** Firebase Authentication (Google sign-in). Project: `collection-showcase-auth`
- **Backend communication:** All mutations are gated behind a valid Firebase session. The `api()` helper in `static/js/api.js` attaches the ID token automatically.
- **Data reads:** Static JSON from `cloud-predict-analytics-data` repo (GitHub Raw, primary) with GCS fallback (`weather` bucket in `fg-polylabs`), via `static/js/data-loader.js`.
- **Deployment:** GitHub Pages via GitHub Actions (`.github/workflows/deploy.yml`).

### GCP Infrastructure

| Resource | Details |
|----------|---------|
| GCP Project | `fg-polylabs` |
| Cloud Run API | `weather-api` — `us-central1` |
| Cloud Run Job | `weather-polymarket` — `us-central1`, runs daily |
| BigQuery | Project `fg-polylabs`, dataset `weather` |
| GCS Bucket | `weather` in `fg-polylabs` (managed by `cloud-predict-analytics-data` repo) |
| Firebase Project | `collection-showcase-auth` |

### Key Files

| Path | Purpose |
|------|---------|
| `hugo.toml` | Hugo config — title, description, params defaults |
| `themes/admin/layouts/` | Hugo templates (baseof, list, index) |
| `themes/admin/layouts/partials/` | head, navbar, footer, scripts partials |
| `static/js/firebase-init.js` | Firebase app init, `authSignOut()`, `isEmailAllowed()`, auth state listener |
| `static/js/api.js` | Authenticated `api(method, path, body)` helper + `qs()` query builder |
| `static/js/app.js` | Global `showToast()` utility |
| `static/js/data-loader.js` | `loadJsonData(filename)` — GitHub-first, GCS-fallback data fetching |
| `static/css/app.css` | Minimal style overrides on top of Bootstrap 5 |
| `content/tracked-cities/_index.md` | Tracked cities section |
| `content/snapshots/_index.md` | Snapshots section |
| `content/debug/_index.md` | Debug section |
| `themes/admin/layouts/debug/list.html` | Debug page — config, auth state, connectivity checks, token viewer |
| `.env.example` | Template for all environment variables |
| `scripts/setup.sh` | Clones sibling repos if not already present |

### Auth Flow

1. User lands on the site and is prompted to sign in via Firebase Auth (Google sign-in).
2. On successful sign-in, Firebase issues an ID token.
3. The frontend attaches the ID token as `Authorization: Bearer <token>` on all backend requests.
4. The backend (`weather-api` Cloud Run service) validates the token via the Firebase Admin SDK.
5. Access is further restricted to a whitelist of allowed emails (`ALLOWED_EMAILS`), enforced on both frontend and backend.

### Development Notes

- Hugo config lives in `hugo.toml`
- Firebase config goes in `.env` — **never commit this file**
- Environment variables are injected as `HUGO_PARAMS_*` and map to `.Site.Params.*` in templates
- The `split .Site.Params.allowed.emails ","` pattern in `head.html` converts the comma-separated email string to a JS array
- To add a new CRUD section: create `content/<section>/_index.md`, add a nav link in `navbar.html`, and create `themes/admin/layouts/<section>/list.html`
- The default `list.html` provides a working CRUD template — update `RESOURCE_PATH` to your backend endpoint

### Working Across Repos

When Claude needs to modify backend API routes, scheduled job logic, or data schemas, it should read/edit files in `../cloud-predict-analytics/`. When modifying shared JSON data structure or the public frontend, it should look in `../cloud-predict-analytics-data/`. Always verify those repos exist locally (run `scripts/setup.sh` if not).
