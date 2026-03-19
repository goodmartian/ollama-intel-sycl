#!/bin/bash
# Smoke test for Ollama with SYCL backend on Intel Arc iGPU
set -euo pipefail

OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
PASS=0
FAIL=0
MODEL="qwen2.5:0.5b"

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $name"
    ((PASS++))
  else
    echo "FAIL: $name"
    ((FAIL++))
  fi
}

echo "=== Ollama SYCL Smoke Test ==="
echo "Host: $OLLAMA_HOST"
echo ""

# 1. API health
check "API reachable" curl -sf "$OLLAMA_HOST/api/tags"

# 2. GPU detected (check systemd or docker logs)
if systemctl is-active ollama-sycl &>/dev/null; then
  check "SYCL GPU detected" bash -c "journalctl -u ollama-sycl --no-pager -n 50 2>&1 | grep -qi 'sycl\|intel.*arc'"
elif docker ps --filter name=ollama-sycl --format '{{.Names}}' 2>/dev/null | grep -q ollama-sycl; then
  check "SYCL GPU detected" bash -c "docker logs ollama-sycl 2>&1 | grep -qi 'sycl\|intel.*arc'"
else
  echo "SKIP: GPU detection (no systemd/docker service found)"
fi

# 3. Inference
echo "Running inference..."
RESPONSE=$(curl -sf "$OLLAMA_HOST/api/generate" -d "{\"model\":\"$MODEL\",\"prompt\":\"Say hello in one word\",\"stream\":false}" 2>/dev/null || true)
if echo "$RESPONSE" | grep -q '"response"'; then
  echo "PASS: Inference works"
  ((PASS++))
  EVAL_COUNT=$(echo "$RESPONSE" | grep -o '"eval_count":[0-9]*' | cut -d: -f2)
  EVAL_DURATION=$(echo "$RESPONSE" | grep -o '"eval_duration":[0-9]*' | cut -d: -f2)
  if [ -n "$EVAL_COUNT" ] && [ -n "$EVAL_DURATION" ] && [ "$EVAL_DURATION" -gt 0 ]; then
    TPS=$(echo "scale=1; $EVAL_COUNT * 1000000000 / $EVAL_DURATION" | bc 2>/dev/null || echo "N/A")
    echo "  Tokens/sec: $TPS"
  fi
else
  echo "FAIL: Inference (model $MODEL may need to be pulled first)"
  ((FAIL++))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
