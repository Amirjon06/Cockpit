#!/usr/bin/env bash
#
# Cockpit backend — server deploy. RUN THIS ON THE SERVER (187.124.92.119),
# from the Backend/ directory, after copying the repo across.
#
#   ssh root@187.124.92.119
#   cd /opt/cockpit/Backend        # wherever you put it
#   cp .env.example .env && nano .env   # fill in the values below, then:
#   bash deploy/deploy.sh
#
# Prereqs already on the server: docker, docker compose, nginx, and the native
# `octopilot` Postgres on 127.0.0.1:5432.
#
# .env must set (see .env.example):
#   APP_ENV=prod
#   SHARED_DATABASE_URL=postgresql+asyncpg://octopilot:***@host.docker.internal:5432/octopilot
#   EMBEDDINGS_BACKEND=sentence-transformers
#   FIREBASE_CREDENTIALS=/srv/secrets/firebase-service-account.json   # from octopilot
#   ALLOW_DEV_USER_HEADER=false        # require Firebase tokens in prod
#
# This script is idempotent — safe to re-run to update.
set -euo pipefail

cd "$(dirname "$0")/.."   # Backend/

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill it in." >&2
  exit 1
fi

echo ">> Building & starting containers (prod overlay)…"
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build

echo ">> Waiting for the API to become healthy…"
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8100/health >/dev/null 2>&1; then
    echo "   API healthy."
    break
  fi
  sleep 2
done

echo ">> Creating DB schemas (cockpit + pgvector)…"
docker compose exec -T cockpit-api python -m scripts.init_databases

echo ">> Readiness:"
curl -fsS http://127.0.0.1:8100/ready || true
echo

echo ">> Done. Next:"
echo "   - Point nginx at 127.0.0.1:8100 (see deploy/nginx-cockpit.conf), reload nginx."
echo "   - Ensure the docker bridge can reach the native Postgres (pg_hba.conf) —"
echo "     the prod overlay maps host.docker.internal to the host gateway."
