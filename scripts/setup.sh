#!/usr/bin/env bash
# setup.sh — Clone all sibling repos for the cloud-predict-analytics multi-repo project.
# Run from anywhere inside cloud-predict-analytics-frontend-admin.
# Repos are cloned as siblings under the same parent directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARENT_DIR="$(dirname "$REPO_ROOT")"

REPOS=(
  "https://github.com/FG-PolyLabs/cloud-predict-analytics"
  "https://github.com/FG-PolyLabs/cloud-predict-analytics-data"
)

echo "Setting up cloud-predict-analytics project repos in: $PARENT_DIR"
echo ""

for repo_url in "${REPOS[@]}"; do
  repo_name="${repo_url##*/}"
  target="$PARENT_DIR/$repo_name"

  if [ -d "$target/.git" ]; then
    echo "  [up-to-date] $repo_name already cloned — pulling latest"
    git -C "$target" pull --ff-only
  else
    echo "  [cloning]    $repo_name"
    git clone "$repo_url" "$target"
  fi
done

echo ""
echo "All repos ready:"
echo "  $PARENT_DIR/cloud-predict-analytics-frontend-admin  (this repo — admin frontend)"
echo "  $PARENT_DIR/cloud-predict-analytics                 (backend API + scheduled jobs)"
echo "  $PARENT_DIR/cloud-predict-analytics-data            (data files + public frontend)"
echo ""
echo "Next: copy .env.example to .env and fill in your Firebase config and backend URL."
