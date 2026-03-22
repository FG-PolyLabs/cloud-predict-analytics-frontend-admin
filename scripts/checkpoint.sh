#!/usr/bin/env bash
# checkpoint.sh — Create a checkpoint tag across all three cloud-predict-analytics repos.
# Only tags a repo if it has new commits since its last checkpoint tag.
# Tags are pushed to origin immediately.
#
# Usage:
#   bash scripts/checkpoint.sh [reason]
#
# Examples:
#   bash scripts/checkpoint.sh
#   bash scripts/checkpoint.sh "before refactoring api layer"

set -euo pipefail

REASON="${1:-}"
TODAY=$(date -u +%Y-%m-%d)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

REPOS=(
  "$PARENT_DIR/cloud-predict-analytics-frontend-admin"
  "$PARENT_DIR/cloud-predict-analytics"
  "$PARENT_DIR/cloud-predict-analytics-data"
)

tag_repo() {
  local repo_path="$1"
  local repo_name
  repo_name="$(basename "$repo_path")"

  if [ ! -d "$repo_path/.git" ]; then
    echo "  [skip]   $repo_name — not found locally (run scripts/setup.sh first)"
    return
  fi

  pushd "$repo_path" > /dev/null

  git fetch --tags --quiet

  local HEAD
  HEAD=$(git rev-parse HEAD)

  local LAST_TAG
  LAST_TAG=$(git tag --list 'checkpoint-*' --sort=-version:refname | head -1)

  local LAST_TAGGED_COMMIT=""
  if [ -n "$LAST_TAG" ]; then
    LAST_TAGGED_COMMIT=$(git rev-list -n 1 "$LAST_TAG")
  fi

  if [ "$HEAD" = "$LAST_TAGGED_COMMIT" ]; then
    echo "  [skip]   $repo_name — no new commits since $LAST_TAG"
    popd > /dev/null
    return
  fi

  # Resolve unique tag name
  local BASE_TAG="checkpoint-${TODAY}"
  local TAG="$BASE_TAG"
  local COUNTER=2
  while git rev-parse "$TAG" >/dev/null 2>&1; do
    TAG="${BASE_TAG}-${COUNTER}"
    COUNTER=$((COUNTER + 1))
  done

  local COMMIT_MSG
  COMMIT_MSG=$(git log -1 --pretty=format:"%s" HEAD)
  local ANNOTATION="Checkpoint ${TAG}"$'\n'"HEAD: ${HEAD:0:8} — ${COMMIT_MSG}"
  if [ -n "$REASON" ]; then
    ANNOTATION="${ANNOTATION}"$'\n'"Reason: ${REASON}"
  fi

  git tag -a "$TAG" -m "$ANNOTATION"
  git push origin "$TAG"
  echo "  [tagged] $repo_name → $TAG"

  popd > /dev/null
}

echo "Creating checkpoint tags (${TODAY})..."
echo ""

for repo in "${REPOS[@]}"; do
  tag_repo "$repo"
done

echo ""
echo "Done."
