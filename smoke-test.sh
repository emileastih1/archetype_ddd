#!/usr/bin/env bash
# smoke-test.sh — cold-start smoke verification (issue #85, ADR-0006)
# Usage: ./smoke-test.sh
# Exit codes: 0 = all green, 1 = one or more services failed

set -euo pipefail

PASS=0
FAIL=0
MAX_WAIT=180  # seconds to wait for each service

check() {
  local name="$1"
  local url="$2"
  local expected="${3:-200}"
  echo -n "  Checking $name ... "
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
  if [ "$status" = "$expected" ] || [ "$status" = "302" ] || { [ "$expected" = "200" ] && [ "$status" != "000" ] && [ "$status" != "500" ]; }; then
    echo "OK ($status)"
    PASS=$((PASS + 1))
  else
    echo "FAIL (got $status, expected $expected)"
    FAIL=$((FAIL + 1))
  fi
}

wait_for() {
  local name="$1"
  local url="$2"
  local elapsed=0
  echo -n "  Waiting for $name"
  while [ $elapsed -lt $MAX_WAIT ]; do
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
    if [ "$status" != "000" ] && [ "$status" != "503" ]; then
      echo " ready ($status)"
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    echo -n "."
  done
  echo " TIMEOUT"
  return 1
}

echo ""
echo "==========================================="
echo "  ICM Stack — Smoke Verification"
echo "==========================================="
echo ""

echo "--- Waiting for services to become ready ---"
wait_for "Keycloak"      "http://localhost:8180/realms/intelligent-content-management/.well-known/openid-configuration"
wait_for "Elasticsearch" "http://localhost:9200/_cluster/health"
wait_for "ICM"           "http://localhost:8085/idm/swagger-ui.html"
wait_for "DMS"           "http://localhost:8086/AiServiceClient/swagger-ui.html"
wait_for "Frontend"      "http://localhost:3000"

echo ""
echo "--- Probing all services ---"

check "Keycloak realm OIDC metadata" \
  "http://localhost:8180/realms/intelligent-content-management/.well-known/openid-configuration"

check "Elasticsearch cluster health" \
  "http://localhost:9200/_cluster/health"

check "ICM Swagger UI" \
  "http://localhost:8085/idm/swagger-ui.html"

check "DMS Swagger UI" \
  "http://localhost:8086/AiServiceClient/swagger-ui.html"

check "Frontend" \
  "http://localhost:3000"

# Ollama models check
echo -n "  Checking Ollama models (gemma3:4b + mxbai-embed-large) ... "
MODELS=$(curl -s http://localhost:11434/api/tags 2>/dev/null || echo "{}")
if echo "$MODELS" | grep -q "gemma3" && echo "$MODELS" | grep -q "mxbai"; then
  echo "OK (both present)"
  PASS=$((PASS + 1))
else
  echo "FAIL (models not found — may still be pulling)"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "==========================================="

[ $FAIL -eq 0 ] && exit 0 || exit 1
