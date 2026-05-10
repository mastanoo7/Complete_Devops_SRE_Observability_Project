#!/bin/bash
# ============================================================
# SLO Compliance Check Script
# Queries Prometheus and reports SLO status for all services
# ============================================================

set -euo pipefail

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
WINDOW="${1:-5m}"
THRESHOLD="${2:-99.9}"
EXIT_CODE=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

query_prometheus() {
    local query="$1"
    curl -s "${PROMETHEUS_URL}/api/v1/query" \
        --data-urlencode "query=${query}" \
        | jq -r '.data.result[0].value[1] // "N/A"'
}

check_slo() {
    local service="$1"
    local slo_target="$2"
    local query="sum(rate(http_requests_total{service=\"${service}\",code!~\"5..\"}[${WINDOW}])) / sum(rate(http_requests_total{service=\"${service}\"}[${WINDOW}]))"

    local availability
    availability=$(query_prometheus "$query")

    if [[ "$availability" == "N/A" ]]; then
        echo -e "${YELLOW}[UNKNOWN]${NC} ${service}: No data available"
        return
    fi

    local availability_pct
    availability_pct=$(echo "$availability * 100" | bc -l | xargs printf "%.4f")

    if (( $(echo "$availability_pct >= $slo_target" | bc -l) )); then
        echo -e "${GREEN}[PASS]${NC} ${service}: ${availability_pct}% (SLO: ${slo_target}%)"
    else
        echo -e "${RED}[FAIL]${NC} ${service}: ${availability_pct}% (SLO: ${slo_target}%)"
        EXIT_CODE=1
    fi
}

check_latency() {
    local service="$1"
    local threshold_ms="$2"
    local query="histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{service=\"${service}\"}[${WINDOW}])) by (le)) * 1000"

    local p99_ms
    p99_ms=$(query_prometheus "$query")

    if [[ "$p99_ms" == "N/A" ]]; then
        echo -e "${YELLOW}[UNKNOWN]${NC} ${service} P99: No data"
        return
    fi

    local p99_rounded
    p99_rounded=$(printf "%.0f" "$p99_ms")

    if (( p99_rounded <= threshold_ms )); then
        echo -e "${GREEN}[PASS]${NC} ${service} P99: ${p99_rounded}ms (SLO: ${threshold_ms}ms)"
    else
        echo -e "${RED}[FAIL]${NC} ${service} P99: ${p99_rounded}ms (SLO: ${threshold_ms}ms)"
        EXIT_CODE=1
    fi
}

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  NexaCommerce SLO Compliance Report              ║"
echo "║  Window: ${WINDOW} | Prometheus: ${PROMETHEUS_URL}"
echo "╚══════════════════════════════════════════════════╝"
echo ""

echo "── Availability SLOs ──────────────────────────────"
check_slo "auth-service"         "99.9"
check_slo "product-service"      "99.9"
check_slo "cart-service"         "99.9"
check_slo "order-service"        "99.95"
check_slo "payment-service"      "99.99"
check_slo "inventory-service"    "99.9"
check_slo "search-service"       "99.5"
check_slo "notification-service" "99.5"
check_slo "frontend"             "99.9"

echo ""
echo "── Latency SLOs (P99) ─────────────────────────────"
check_latency "auth-service"      200
check_latency "product-service"   500
check_latency "cart-service"      100
check_latency "order-service"     2000
check_latency "payment-service"   3000
check_latency "search-service"    500

echo ""
echo "── Error Budget ───────────────────────────────────"
BUDGET_QUERY='1 - ((1 - sum(rate(http_requests_total{namespace="nexacommerce-prod",code=~"5.."}[30d])) / sum(rate(http_requests_total{namespace="nexacommerce-prod"}[30d]))) / (1 - 0.999))'
BUDGET=$(query_prometheus "$BUDGET_QUERY")
if [[ "$BUDGET" != "N/A" ]]; then
    BUDGET_PCT=$(echo "$BUDGET * 100" | bc -l | xargs printf "%.1f")
    if (( $(echo "$BUDGET_PCT >= 50" | bc -l) )); then
        echo -e "${GREEN}[OK]${NC} Error budget remaining: ${BUDGET_PCT}%"
    elif (( $(echo "$BUDGET_PCT >= 10" | bc -l) )); then
        echo -e "${YELLOW}[WARN]${NC} Error budget remaining: ${BUDGET_PCT}% — slow down deployments"
    else
        echo -e "${RED}[CRITICAL]${NC} Error budget remaining: ${BUDGET_PCT}% — freeze deployments!"
        EXIT_CODE=1
    fi
fi

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}✅ All SLOs passing${NC}"
else
    echo -e "${RED}❌ SLO violations detected${NC}"
fi
echo ""

exit $EXIT_CODE
