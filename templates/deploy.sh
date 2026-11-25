#!/usr/bin/env bash
# scripts/deploy.sh — deploy the checked-out commit with Docker Compose, with automatic rollback. A skeleton: adapt the
# steps to your app. Copied from the factory repo's templates/deploy.sh.
#
# Contract with deploy.yml and deploy_incident.sh:
#   exit 0 = deployed; 1 = failed and rolled back; 2 = failed and the rollback failed too.
#   On failure, the failing step's name goes to $DEPLOY_STATE/failed_step and the output to $DEPLOY_STATE/deploy.log.
#   A successful deploy records its commit in $DEPLOY_STATE/last_good (the rollback target).
#
# Environment (optional): ENV_FILE (the host's .env, copied into the checkout), DEPLOY_STATE, APP_URL.
set -uo pipefail

ENV_FILE="${ENV_FILE:-$HOME/app/.env}"
DEPLOY_STATE="${DEPLOY_STATE:-$HOME/.app-deploy}"
APP_URL="${APP_URL:-http://127.0.0.1:8000}"
mkdir -p "$DEPLOY_STATE"
LOG="$DEPLOY_STATE/deploy.log"; : >"$LOG"
cd "$(git rev-parse --show-toplevel)"

step_build()   { docker compose build; }
step_migrate() { docker compose run --rm app alembic upgrade head; }      # or your migration command
step_up()      { docker compose up -d --remove-orphans; }
step_smoke()   {                                                           # wait for health, then check key pages
  for _ in $(seq 1 30); do curl -fsS "$APP_URL/healthz" >/dev/null && break; sleep 2; done
  curl -fsS "$APP_URL/healthz" >/dev/null
  # add: each important page returns 200, a phone-size Playwright check of the live app, etc.
}

deploy_here() {
  cp "$ENV_FILE" .env 2>/dev/null || true
  for step in build migrate up smoke; do
    echo "STEP $step" | tee -a "$LOG"
    if ! "step_$step" >>"$LOG" 2>&1; then echo "$step" >"$DEPLOY_STATE/failed_step"; return 1; fi
  done
}

if deploy_here; then
  git rev-parse HEAD >"$DEPLOY_STATE/last_good"; rm -f "$DEPLOY_STATE/failed_step"; echo "deployed $(git rev-parse --short HEAD)"; exit 0
fi
failed="$(cat "$DEPLOY_STATE/failed_step")"
prev="$(cat "$DEPLOY_STATE/last_good" 2>/dev/null || true)"
[ -n "$prev" ] || { echo "failed at $failed; no last good commit to roll back to"; exit 2; }
echo "failed at $failed; rolling back to $prev" | tee -a "$LOG"
git checkout -q "$prev" && deploy_here && { echo "$failed" >"$DEPLOY_STATE/failed_step"; exit 1; }
echo "$failed" >"$DEPLOY_STATE/failed_step"; echo "rollback failed too" | tee -a "$LOG"; exit 2
