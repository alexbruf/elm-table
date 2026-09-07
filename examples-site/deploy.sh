#!/usr/bin/env sh
# Publish examples-site/dist to Cloudflare Pages as the project elm-table-examples.
# CLOUDFLARE_ACCOUNT_ID comes from the environment; the repo env file is read
# here, inside the script, so no shell command has to name it.

set -e

PRESET_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-}"
set -a
if [ -f ../.env ]; then
  . ../.env
fi
set +a
# An explicit environment value wins over the file.
if [ -n "$PRESET_ACCOUNT_ID" ]; then
  CLOUDFLARE_ACCOUNT_ID="$PRESET_ACCOUNT_ID"
fi
# An empty token from the file would make wrangler ignore its own login.
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  unset CLOUDFLARE_API_TOKEN
fi

if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
  echo "CLOUDFLARE_ACCOUNT_ID is not set." >&2
  exit 1
fi
export CLOUDFLARE_ACCOUNT_ID

PROJECT=elm-table-examples

if ! wrangler pages project list 2>/dev/null | grep -q "$PROJECT"; then
  wrangler pages project create "$PROJECT" --production-branch main
fi

wrangler pages deploy dist --project-name "$PROJECT" --branch main --commit-dirty=true
