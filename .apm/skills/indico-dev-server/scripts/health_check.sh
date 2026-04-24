#!/usr/bin/env bash
# Health check for Indico dev stack components.
# Usage: bash health_check.sh [--all | --indico | --chainlit | --celery | --webpack | --postgres | --redis]
# No args = --all

set -euo pipefail

INDICO_URL="${INDICO_URL:-http://localhost:8000}"
CHAINLIT_URL="${CHAINLIT_URL:-http://127.0.0.1:8001}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
FAIL_COUNT=0
ok()   { printf "${GREEN}✓${NC} %s\n" "$1"; }
fail() { printf "${RED}✗${NC} %s\n" "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { printf "${YELLOW}⚠${NC} %s\n" "$1"; }

check_indico() {
  if curl -sf -o /dev/null -m 5 "${INDICO_URL}/"; then
    ok "Indico web server responding at ${INDICO_URL}"
  else
    fail "Indico web server NOT responding at ${INDICO_URL}"
  fi
}

check_chainlit() {
  if curl -sf -o /dev/null -m 5 "${CHAINLIT_URL}/"; then
    ok "Chainlit responding at ${CHAINLIT_URL}"
  else
    fail "Chainlit NOT responding at ${CHAINLIT_URL}"
  fi
}

check_celery() {
  if pgrep -f 'celery.*worker' >/dev/null 2>&1; then
    ok "Celery worker process running (PID $(pgrep -f 'celery.*worker' | head -1))"
  else
    fail "No Celery worker process found"
  fi
}

check_webpack() {
  if pgrep -f 'build-assets.*--watch' >/dev/null 2>&1; then
    ok "Webpack watcher running (PID $(pgrep -f 'build-assets.*--watch' | head -1))"
  else
    warn "Webpack watcher not running (optional — only needed for asset changes)"
  fi
}

check_postgres() {
  if pg_isready -q 2>/dev/null; then
    ok "PostgreSQL accepting connections"
  elif pgrep -x postgres >/dev/null 2>&1; then
    ok "PostgreSQL process running"
  else
    fail "PostgreSQL not detected"
  fi
}

check_redis() {
  if redis-cli ping 2>/dev/null | grep -q PONG; then
    ok "Redis responding (PONG)"
  else
    fail "Redis not responding"
  fi
}

run_all() {
  echo "=== Indico Dev Stack Health Check ==="
  echo ""
  echo "--- Infrastructure ---"
  check_postgres
  check_redis
  echo ""
  echo "--- Application ---"
  check_indico
  check_chainlit
  check_celery
  check_webpack
  echo ""
}

target="${1:---all}"
case "$target" in
  --all)      run_all ;;
  --indico)   check_indico ;;
  --chainlit) check_chainlit ;;
  --celery)   check_celery ;;
  --webpack)  check_webpack ;;
  --postgres) check_postgres ;;
  --redis)    check_redis ;;
  *) echo "Usage: $0 [--all|--indico|--chainlit|--celery|--webpack|--postgres|--redis]"; exit 1 ;;
esac

[ "$FAIL_COUNT" -eq 0 ] || exit 1
