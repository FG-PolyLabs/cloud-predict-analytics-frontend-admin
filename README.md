# cloud-predict-analytics-frontend-admin

Admin frontend for the cloud-predict-analytics system. Authenticated users can manage data via the backend API; data is read from the `cloud-predict-analytics-data` repo (GitHub Raw) with GCS as fallback.

## Multi-Repo Project

This is one of three repositories:

| Repo | Role |
|------|------|
| [`cloud-predict-analytics-frontend-admin`](https://github.com/FG-PolyLabs/cloud-predict-analytics-frontend-admin) | **This repo** — admin UI (Hugo + Firebase Auth) |
| [`cloud-predict-analytics`](https://github.com/FG-PolyLabs/cloud-predict-analytics) | Backend — Cloud Run API (`weather-api`) + daily scheduled job (`weather-polymarket`) |
| [`cloud-predict-analytics-data`](https://github.com/FG-PolyLabs/cloud-predict-analytics-data) | Data files (JSON) updated by backend + public frontend |

Clone all sibling repos at once:

```bash
bash scripts/setup.sh
```

## Architecture

```
Browser (Admin)
  │
  ├── Read (static JSON data)
  │     └── GitHub Raw (FG-PolyLabs/cloud-predict-analytics-data)
  │           └── GCS fallback (gs://weather, project: fg-polylabs)
  │
  └── Write (create, update, delete)
        └── Cloud Run API (weather-api, us-central1, project: fg-polylabs)
              ├── Firebase Auth token verified
              ├── Operation applied to BigQuery (dataset: weather, project: fg-polylabs)
              └── Updated JSON published to cloud-predict-analytics-data + GCS
```

**Reads** are served from static JSON files published by the backend after each mutation. The frontend fetches from GitHub first and falls back to GCS.

**Writes** go to the `weather-api` Cloud Run service, which validates the Firebase token, applies the change to BigQuery, and republishes data to GitHub and GCS.

**Scheduled updates** are handled by the `weather-polymarket` Cloud Run job (daily), which runs independently of user actions.

## Tech Stack

- **[Hugo](https://gohugo.io/)** — static site generator
- **Bootstrap 5** — UI framework
- **Firebase Auth** (`collection-showcase-auth` project) — Google sign-in, ID token issuance
- **GitHub Pages** — hosting via GitHub Actions
- **GitHub Raw / GCS** — static data sources for reads

## GCP Infrastructure

| Resource | Details |
|----------|---------|
| GCP Project | `fg-polylabs` |
| Cloud Run API | [`weather-api`](https://console.cloud.google.com/run/detail/us-central1/weather-api/metrics?project=fg-polylabs) — `us-central1` |
| Cloud Run Job | [`weather-polymarket`](https://console.cloud.google.com/run/jobs/details/us-central1/weather-polymarket/executions?project=fg-polylabs) — daily |
| BigQuery | Project `fg-polylabs`, dataset `weather` |
| GCS Bucket | `weather` in `fg-polylabs` |
| Firebase Project | `collection-showcase-auth` |

## Local Development

1. Clone all repos:
   ```bash
   bash scripts/setup.sh
   ```

2. Copy `.env.example` to `.env` and fill in your Firebase API key, App ID, and messaging sender ID. The non-sensitive defaults (auth domain, project ID, storage bucket, data repo, GCS bucket) are already pre-filled.

3. Start the dev server:
   ```bash
   source .env && \
     HUGO_PARAMS_FIREBASE_API_KEY=$HUGO_PARAMS_FIREBASE_API_KEY \
     HUGO_PARAMS_FIREBASE_AUTH_DOMAIN=$HUGO_PARAMS_FIREBASE_AUTH_DOMAIN \
     HUGO_PARAMS_FIREBASE_PROJECT_ID=$HUGO_PARAMS_FIREBASE_PROJECT_ID \
     HUGO_PARAMS_FIREBASE_STORAGE_BUCKET=$HUGO_PARAMS_FIREBASE_STORAGE_BUCKET \
     HUGO_PARAMS_FIREBASE_MESSAGING_SENDER_ID=$HUGO_PARAMS_FIREBASE_MESSAGING_SENDER_ID \
     HUGO_PARAMS_FIREBASE_APP_ID=$HUGO_PARAMS_FIREBASE_APP_ID \
     HUGO_PARAMS_BACKENDURL=$HUGO_PARAMS_BACKENDURL \
     HUGO_PARAMS_ALLOWED_EMAILS=$HUGO_PARAMS_ALLOWED_EMAILS \
     HUGO_PARAMS_GITHUB_DATA_REPO=$HUGO_PARAMS_GITHUB_DATA_REPO \
     HUGO_PARAMS_GCS_DATA_BUCKET=$HUGO_PARAMS_GCS_DATA_BUCKET \
     hugo server --port 1313
   ```

4. Open [http://localhost:1313](http://localhost:1313) and sign in with an allowed email.

## Configuration

All configuration is supplied via `HUGO_PARAMS_*` environment variables. See `.env.example` for the full list with project-specific defaults.

### GitHub Actions Variables (non-sensitive)

| Variable | Value |
|----------|-------|
| `HUGO_PARAMS_FIREBASE_AUTH_DOMAIN` | `collection-showcase-auth.firebaseapp.com` |
| `HUGO_PARAMS_FIREBASE_PROJECT_ID` | `collection-showcase-auth` |
| `HUGO_PARAMS_FIREBASE_STORAGE_BUCKET` | `collection-showcase-auth.firebasestorage.app` |
| `HUGO_PARAMS_BACKENDURL` | Cloud Run `weather-api` URL |
| `HUGO_PARAMS_ALLOWED_EMAILS` | Comma-separated admin emails |
| `HUGO_PARAMS_GCS_DATA_BUCKET` | `fg-polylabs-data` |
| `HUGO_PARAMS_GITHUB_DATA_REPO` | `FG-PolyLabs/cloud-predict-analytics-data` |

### GitHub Actions Secrets (sensitive)

| Secret | Purpose |
|--------|---------|
| `HUGO_PARAMS_FIREBASE_API_KEY` | Firebase API key |
| `HUGO_PARAMS_FIREBASE_APP_ID` | Firebase app ID |
| `HUGO_PARAMS_FIREBASE_MESSAGING_SENDER_ID` | Firebase messaging sender ID |

## Adding a New Section

1. Create the content directory:
   ```bash
   mkdir -p content/my-section
   echo $'---\ntitle: "My Section"\n---' > content/my-section/_index.md
   ```
2. Add a nav link in `themes/admin/layouts/partials/navbar.html`.
3. Optionally create a custom layout at `themes/admin/layouts/my-section/list.html`.
4. Update the `RESOURCE_PATH` constant to match the backend endpoint in `weather-api`.
