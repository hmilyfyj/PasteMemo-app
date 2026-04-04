#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$HOME/Applications/PasteMemo Dev.app"
SIGNING_IDENTITY="${PASTEMEMO_SIGNING_IDENTITY:-PasteMemo Dev Code Signing}"
BUNDLE_ID="${PASTEMEMO_BUNDLE_ID:-com.lifedever.PasteMemo.dev}"

cd "$ROOT_DIR"

PASTEMEMO_APP_DIR="$APP_DIR" \
PASTEMEMO_SIGNING_IDENTITY="$SIGNING_IDENTITY" \
PASTEMEMO_BUNDLE_ID="$BUNDLE_ID" \
./scripts/rebuild_and_open.sh

echo
echo "稳定开发版已更新"
echo "请固定授权这个路径一次: $APP_DIR"
