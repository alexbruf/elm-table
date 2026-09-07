#!/usr/bin/env sh
# Publish demo/dist to Cloudflare Pages as the project elm-table-demo.
#
# CLOUDFLARE_ACCOUNT_ID comes from the environment. The repo env file is read
# here, inside the script, so no shell command has to name it.

set -e

set -a
if [ -f ../.env ]; then
  . ../.env
fi
set +a

if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
  echo "CLOUDFLARE_ACCOUNT_ID is not set." >&2
  exit 1
fi
export CLOUDFLARE_ACCOUNT_ID

PROJECT=elm-table-demo

if ! wrangler pages project list 2>/dev/null | grep -q "$PROJECT"; then
  wrangler pages project create "$PROJECT" --production-branch main
fi

wrangler pages deploy dist --project-name "$PROJECT" --branch main --commit-dirty=true
