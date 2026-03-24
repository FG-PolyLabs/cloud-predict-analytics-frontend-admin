#!/usr/bin/env bash
# health-check.sh — Daily system health check for cloud-predict-analytics
# Run after 03:30 UTC to give both jobs time to complete.
# Usage: bash scripts/health-check.sh

set -euo pipefail

PROJECT=fg-polylabs
REGION=us-central1
BUCKET=fg-polylabs-weather-data
GH_REPO=FG-PolyLabs/cloud-predict-analytics-data
API_URL=https://weather-api-clyfbx4tja-uc.a.run.app

PASS="[PASS]"
FAIL="[FAIL]"
WARN="[WARN]"
SKIP="[SKIP]"

TODAY=$(date -u +%Y-%m-%d)
YESTERDAY=$(date -u -d "yesterday" +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d)

failures=0

check() {
  local label="$1"
  local status="$2"   # pass | fail | warn | skip
  local detail="$3"
  case "$status" in
    pass) echo "  $PASS $label — $detail" ;;
    fail) echo "  $FAIL $label — $detail"; failures=$((failures + 1)) ;;
    warn) echo "  $WARN $label — $detail" ;;
    skip) echo "  $SKIP $label — $detail" ;;
  esac
}

echo ""
echo "================================================="
echo " cloud-predict-analytics — Daily Health Check"
echo " $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "================================================="

# ---------------------------------------------------------------------------
# Step 1: GCS file freshness
# ---------------------------------------------------------------------------
echo ""
echo "[ Step 1 ] GCS file freshness"

for file in data/snapshots.jsonl data/tracked_cities.jsonl; do
  info=$(gcloud storage ls -l "gs://$BUCKET/$file" --project="$PROJECT" 2>/dev/null || true)
  if [[ -z "$info" ]]; then
    check "$file" fail "file not found in GCS"
  else
    mod=$(echo "$info" | awk 'NR==1 {print $2}' | cut -c1-10)
    if [[ "$mod" == "$TODAY" ]]; then
      size=$(echo "$info" | awk 'NR==1 {print $1}')
      check "$file" pass "updated today ($mod), size $size bytes"
    else
      check "$file" fail "last modified $mod (expected $TODAY)"
    fi
  fi
done

# ---------------------------------------------------------------------------
# Step 2: GitHub file freshness
# ---------------------------------------------------------------------------
echo ""
echo "[ Step 2 ] GitHub file freshness"

for file in data/snapshots.jsonl data/tracked_cities.jsonl; do
  response=$(curl -sf "https://api.github.com/repos/$GH_REPO/commits?path=$file&per_page=1" 2>/dev/null || true)
  if [[ -z "$response" ]]; then
    check "$file (GitHub)" warn "could not reach GitHub API"
  else
    commit_date=$(echo "$response" | grep -o '"date": "[^"]*"' | head -1 | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' || true)
    if [[ "$commit_date" == "$TODAY" ]]; then
      check "$file (GitHub)" pass "last commit today ($commit_date)"
    elif [[ "$file" == "data/tracked_cities.jsonl" ]]; then
      # tracked_cities only changes when cities are added/removed — not necessarily daily
      check "$file (GitHub)" warn "last commit $commit_date (cities may not have changed today)"
    else
      check "$file (GitHub)" fail "last commit $commit_date (expected $TODAY)"
    fi
  fi
done

# ---------------------------------------------------------------------------
# Step 3: weather-sync Cloud Run job
# ---------------------------------------------------------------------------
echo ""
echo "[ Step 3 ] weather-sync Cloud Run job"

sync_exec=$(gcloud run jobs executions list \
  --job=weather-sync \
  --region="$REGION" \
  --project="$PROJECT" \
  --limit=1 \
  --format="value(name, status.completionTime, status.conditions[0].type, status.conditions[0].status)" \
  2>/dev/null || true)

if [[ -z "$sync_exec" ]]; then
  check "weather-sync execution" fail "no executions found"
else
  exec_name=$(echo "$sync_exec" | awk '{print $1}')
  comp_time=$(echo "$sync_exec" | awk '{print $2}')
  condition=$(echo "$sync_exec" | awk '{print $3}')
  status=$(echo "$sync_exec" | awk '{print $4}')
  comp_date=$(echo "$comp_time" | cut -c1-10)

  if [[ "$condition" == "Completed" && "$status" == "True" && "$comp_date" == "$TODAY" ]]; then
    check "weather-sync execution" pass "Completed at $comp_time"
  elif [[ "$condition" == "Completed" && "$status" == "True" ]]; then
    check "weather-sync execution" fail "Completed but on $comp_date, not today"
  else
    check "weather-sync execution" fail "status=$condition/$status at $comp_time"
  fi

  # Check for errors in logs
  errors=$(gcloud logging read \
    "resource.type=cloud_run_job AND resource.labels.job_name=weather-sync AND resource.labels.execution_name=$exec_name AND severity>=ERROR" \
    --project="$PROJECT" \
    --limit=5 \
    --format="value(textPayload)" \
    2>/dev/null || true)

  if [[ -z "$errors" ]]; then
    check "weather-sync logs" pass "no ERROR-level entries"
  else
    check "weather-sync logs" fail "errors found:"
    echo "$errors" | sed 's/^/      /'
  fi
fi

# ---------------------------------------------------------------------------
# Step 4: doomsday-polymarket Cloud Run job
# ---------------------------------------------------------------------------
echo ""
echo "[ Step 4 ] doomsday-polymarket Cloud Run job"

poly_exec=$(gcloud run jobs executions list \
  --job=doomsday-polymarket \
  --region="$REGION" \
  --project="$PROJECT" \
  --limit=1 \
  --format="value(name, status.completionTime, status.conditions[0].type, status.conditions[0].status)" \
  2>/dev/null || true)

if [[ -z "$poly_exec" ]]; then
  check "doomsday-polymarket execution" fail "no executions found"
else
  exec_name=$(echo "$poly_exec" | awk '{print $1}')
  comp_time=$(echo "$poly_exec" | awk '{print $2}')
  condition=$(echo "$poly_exec" | awk '{print $3}')
  status=$(echo "$poly_exec" | awk '{print $4}')
  comp_date=$(echo "$comp_time" | cut -c1-10)

  if [[ "$condition" == "Completed" && "$status" == "True" && "$comp_date" == "$TODAY" ]]; then
    check "doomsday-polymarket execution" pass "Completed at $comp_time"
  elif [[ "$condition" == "Completed" && "$status" == "True" ]]; then
    check "doomsday-polymarket execution" fail "Completed but on $comp_date, not today"
  else
    check "doomsday-polymarket execution" fail "status=$condition/$status at $comp_time"
  fi

  # Check for errors in logs
  errors=$(gcloud logging read \
    "resource.type=cloud_run_job AND resource.labels.job_name=doomsday-polymarket AND resource.labels.execution_name=$exec_name AND severity>=ERROR" \
    --project="$PROJECT" \
    --limit=5 \
    --format="value(textPayload)" \
    2>/dev/null || true)

  if [[ -z "$errors" ]]; then
    check "doomsday-polymarket logs" pass "no ERROR-level entries"
  else
    check "doomsday-polymarket logs" fail "errors found:"
    echo "$errors" | sed 's/^/      /'
  fi
fi

# ---------------------------------------------------------------------------
# Step 5: BigQuery row count for yesterday
# ---------------------------------------------------------------------------
echo ""
echo "[ Step 5 ] BigQuery — yesterday's data ($YESTERDAY)"

if ! command -v bq &>/dev/null; then
  check "BigQuery row count" skip "bq CLI not available"
else
  bq_out=$(bq query \
    --project_id="$PROJECT" \
    --use_legacy_sql=false \
    --format=csv \
    "SELECT COUNT(*) as row_count FROM \`$PROJECT.weather.snapshots\` WHERE DATE(timestamp) = '$YESTERDAY'" \
    2>/dev/null || true)

  if [[ -z "$bq_out" ]]; then
    check "BigQuery row count" warn "query failed or returned no output (check bq CLI)"
  else
    row_count=$(echo "$bq_out" | tail -1 | tr -d '[:space:]')
    if [[ "$row_count" =~ ^[0-9]+$ ]] && [[ "$row_count" -gt 0 ]]; then
      check "BigQuery row count" pass "$row_count rows for $YESTERDAY"
    else
      check "BigQuery row count" fail "0 rows found for $YESTERDAY"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Step 6: weather-api service health
# ---------------------------------------------------------------------------
echo ""
echo "[ Step 6 ] weather-api service"

svc=$(gcloud run services describe weather-api \
  --region="$REGION" \
  --project="$PROJECT" \
  --format="value(status.conditions[0].type, status.conditions[0].status)" \
  2>/dev/null || true)

if [[ -z "$svc" ]]; then
  check "weather-api Cloud Run status" fail "could not describe service"
else
  cond_type=$(echo "$svc" | awk '{print $1}')
  cond_status=$(echo "$svc" | awk '{print $2}')
  if [[ "$cond_type" == "Ready" && "$cond_status" == "True" ]]; then
    check "weather-api Cloud Run status" pass "Ready"
  else
    check "weather-api Cloud Run status" fail "status=$cond_type/$cond_status"
  fi
fi

http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$API_URL/health" 2>/dev/null || echo "000")
if [[ "$http_code" == "200" ]]; then
  check "weather-api smoke test (GET /health)" pass "HTTP $http_code"
elif [[ "$http_code" == "000" ]]; then
  check "weather-api smoke test (GET /health)" fail "no response (timeout or unreachable)"
else
  check "weather-api smoke test (GET /health)" fail "HTTP $http_code"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "================================================="
if [[ "$failures" -eq 0 ]]; then
  echo " All checks passed."
else
  echo " $failures check(s) FAILED — review output above."
fi
echo "================================================="
echo ""

exit $((failures > 0 ? 1 : 0))
