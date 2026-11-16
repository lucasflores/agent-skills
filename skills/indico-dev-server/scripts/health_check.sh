#!/usr/bin/env bash
# Health check for Indico dev stack components.
# Usage: bash health_check.sh [--all | --indico | --chainlit | --celery | --postgres | --redis]
# No args = --all

set -euo pipefail

INDICO_URL="${INDICO_URL:-http://127.0.0.1:8000}"
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

# Chat needs the worker on all of these; a worker without them still "runs" while chat stays pending.
CELERY_QUEUES="celery assistant assistant_bulk teams_notes"

check_celery() {
  local pid cmd queues q missing found=0
  for pid in $(pgrep -f 'celery.*worker' || true); do
    case "$(ps -o comm= -p "$pid")" in *sh) continue;; esac  # skip a shell that launched the worker
    cmd=$(ps -o command= -p "$pid") || continue
    found=1
    # No -Q means Celery's default queue only
    queues=$(printf '%s\n' "$cmd" | grep -oE -- '(-Q|--queues)[ =][^ ]+' | sed -E 's/^(-Q|--queues)[ =]//' | tr ',' ' ' || true)
    queues=" ${queues:-celery} "
    missing=""
    for q in $CELERY_QUEUES; do
      case "$queues" in *" $q "*) ;; *) missing="$missing $q";; esac
    done
    if [ -z "$missing" ]; then
      ok "Celery worker running on all queues (PID $pid)"
    else
      fail "Celery worker PID $pid is missing queue(s):$missing (start it with -Q celery,assistant,assistant_bulk,teams_notes)"
    fi
  done
  [ "$found" -eq 1 ] || fail "No Celery worker process found"
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
  echo ""
}

target="${1:---all}"
case "$target" in
  --all)      run_all ;;
  --indico)   check_indico ;;
  --chainlit) check_chainlit ;;
  --celery)   check_celery ;;
  --postgres) check_postgres ;;
  --redis)    check_redis ;;
  *) echo "Usage: $0 [--all|--indico|--chainlit|--celery|--postgres|--redis]"; exit 1 ;;
esac

[ "$FAIL_COUNT" -eq 0 ] || exit 1
