#!/bin/bash

# Spot k6 Load Test Runner
# Usage: ./run.sh [test_type] [options]
# Examples:
#   ./run.sh smoke
#   ./run.sh load
#   ./run.sh stress
#   ./run.sh spike

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"
ENV_FILE="${SCRIPT_DIR}/.env"

# ==========================================
# Load .env file
# ==========================================
if [ -f "${ENV_FILE}" ]; then
  echo "Loading environment from .env..."
  set -a
  source "${ENV_FILE}"
  set +a
else
  echo "Warning: .env file not found. Using defaults."
fi

# ==========================================
# Parse YAML config (simple parser)
# ==========================================
parse_yaml() {
  local file=$1
  local prefix=$2
  local s='[[:space:]]*'
  local w='[a-zA-Z0-9_]*'
  sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1\2=\"\3\"|p" \
      -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1\2=\"\3\"|p" "$file" | \
  sed -ne "s|^\($s\)$prefix\1\($w\)=\(.*\)|\2=\3|p"
}

# Load config.yaml
if [ -f "${CONFIG_FILE}" ]; then
  echo "Loading config from config.yaml..."

  # Extract values using grep/sed (portable approach)
  BASE_URL=$(grep -A1 "^server:" "${CONFIG_FILE}" | grep "base_url" | sed 's/.*: *"\([^"]*\)".*/\1/' | head -1)
  STORE_ID=$(grep -A1 "^test_data:" "${CONFIG_FILE}" | grep "store_id" | sed 's/.*: *"\([^"]*\)".*/\1/' | head -1)
  MENU_ID=$(grep "menu_id" "${CONFIG_FILE}" | sed 's/.*: *"\([^"]*\)".*/\1/' | head -1)

  # Set defaults if not found
  BASE_URL="${BASE_URL:-http://localhost:8080}"
else
  echo "Warning: config.yaml not found. Using defaults."
  BASE_URL="${BASE_URL:-http://localhost:8080}"
fi

# ==========================================
# Test type and mode selection
# ==========================================
TEST_TYPE="${1:-smoke}"
TEST_MODE="${2:-all}"      # browse, integrity, all
BROWSE_MODE="${3:-random}" # random, fixed

# Validate TEST_MODE
case "$TEST_MODE" in
  browse|integrity|all)
    ;;
  *)
    echo "Error: Unknown test mode: $TEST_MODE"
    echo ""
    echo "Available test modes:"
    echo "  browse    - Read-only tests (store, menu, order list)"
    echo "  integrity - Data integrity tests (order creation + validation)"
    echo "  all       - All tests (default)"
    exit 1
    ;;
esac

# Validate BROWSE_MODE
case "$BROWSE_MODE" in
  random|fixed)
    ;;
  *)
    echo "Error: Unknown browse mode: $BROWSE_MODE"
    echo ""
    echo "Available browse modes:"
    echo "  random - Random store/menu selection each iteration"
    echo "  fixed  - Same store/menu for all iterations"
    exit 1
    ;;
esac

case "$TEST_TYPE" in
  smoke)
    SCRIPT="${SCRIPT_DIR}/tests/smoke.js"
    ;;
  load)
    SCRIPT="${SCRIPT_DIR}/tests/load.js"
    ;;
  stress)
    SCRIPT="${SCRIPT_DIR}/tests/stress.js"
    ;;
  spike)
    SCRIPT="${SCRIPT_DIR}/tests/spike.js"
    ;;
  order-smoke|order-load|order-stress|order-spike)
      ORDER_TYPE="${TEST_TYPE#order-}"
      SCRIPT="${SCRIPT_DIR}/tests/order-only.js"
      TEST_TYPE="order-only"
      ;;
  *)
    if [ -f "$TEST_TYPE" ]; then
      SCRIPT="$TEST_TYPE"
    elif [ -f "${SCRIPT_DIR}/$TEST_TYPE" ]; then
      SCRIPT="${SCRIPT_DIR}/$TEST_TYPE"
    else
      echo "Error: Unknown test type: $TEST_TYPE"
      echo ""
      echo "Available test types:"
      echo "  smoke   - Quick verification (1 VU, 30s)"
      echo "  load    - Normal load (10 VUs, 5m)"
      echo "  stress  - Stress test (100 VUs)"
      echo "  spike   - Spike test (sudden 100 VUs)"
      echo ""
      echo "Available test modes (2nd argument):"
      echo "  browse    - Read-only tests"
      echo "  integrity - Data integrity tests"
      echo "  all       - All tests (default)"
      exit 1
    fi
    ;;
esac

# Create logs directory
mkdir -p "${LOGS_DIR}"

# Log file paths
JSON_LOG="${LOGS_DIR}/${TIMESTAMP}_${TEST_TYPE}_result.json"
SUMMARY_LOG="${LOGS_DIR}/${TIMESTAMP}_${TEST_TYPE}_summary.json"

# Shift to remove test type, mode, and browse mode arguments
shift 2>/dev/null || true
shift 2>/dev/null || true
shift 2>/dev/null || true

echo "=========================================="
echo "  Spot k6 Load Test Runner"
echo "=========================================="
echo "Test Type:   ${TEST_TYPE}"
echo "Test Mode:   ${TEST_MODE}"
echo "Browse Mode: ${BROWSE_MODE}"
echo "Base URL:    ${BASE_URL}"
echo "Store ID:    ${STORE_ID:-not set}"
echo "Timestamp:   ${TIMESTAMP}"
echo "=========================================="

# ==========================================
# Run k6 with environment variables
# ==========================================
k6 run \
  --out json="${JSON_LOG}" \
  --summary-export="${SUMMARY_LOG}" \
  -e BASE_URL="${BASE_URL}" \
  -e TEST_TYPE="${ORDER_TYPE:-smoke}" \
  -e STORE_ID="${STORE_ID}" \
  -e MENU_ID="${MENU_ID}" \
  -e TEST_MODE="${TEST_MODE}" \
  -e BROWSE_MODE="${BROWSE_MODE}" \
  -e CUSTOMER_USERNAME="${CUSTOMER_USERNAME:-customer}" \
  -e CUSTOMER_PASSWORD="${CUSTOMER_PASSWORD:-customer}" \
  -e OWNER_USERNAME="${OWNER_USERNAME:-owner}" \
  -e OWNER_PASSWORD="${OWNER_PASSWORD:-owner}" \
  -e CHEF_USERNAME="${CHEF_USERNAME:-chef}" \
  -e CHEF_PASSWORD="${CHEF_PASSWORD:-chef}" \
  -e MANAGER_USERNAME="${MANAGER_USERNAME:-manager}" \
  -e MANAGER_PASSWORD="${MANAGER_PASSWORD:-manager}" \
  -e MASTER_USERNAME="${MASTER_USERNAME:-master}" \
  -e MASTER_PASSWORD="${MASTER_PASSWORD:-master}" \
  "${SCRIPT}" \
  "$@"

echo ""
echo "=========================================="
echo "  Test Completed!"
echo "=========================================="
echo "Results saved to:"
echo "  - ${JSON_LOG}"
echo "  - ${SUMMARY_LOG}"
echo "=========================================="