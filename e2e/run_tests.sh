#!/bin/bash
# frozen_string_literal: true

# E2E test runner for maxprocs gem
# Tests cgroup CPU detection with various Docker CPU limits

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="ruby:3.4-slim"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((++passed)) || true
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((++failed)) || true
}

# Run a single test case
# Arguments: test_name, cpu_limit, expected_count, expected_limited, expected_version
run_test() {
    local test_name="$1"
    local cpu_limit="$2"
    local expected_count="$3"
    local expected_limited="$4"
    local expected_version="${5:-}"

    log_info "Running test: $test_name (cpus=$cpu_limit, expected=$expected_count)"

    local env_args="-e EXPECTED_COUNT=$expected_count -e EXPECTED_LIMITED=$expected_limited"
    if [ -n "$expected_version" ]; then
        env_args="$env_args -e EXPECTED_VERSION=$expected_version"
    fi

    local cpu_args=""
    if [ -n "$cpu_limit" ]; then
        cpu_args="--cpus=$cpu_limit"
    fi

    if docker run --rm -v $PROJECT_ROOT:/app -w /app $cpu_args $env_args "$IMAGE_NAME" ruby e2e/test_cgroup.rb 2>&1; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
    echo
}

# Get host CPU count for unlimited test
get_host_cpus() {
    if command -v nproc &> /dev/null; then
        nproc
    elif [ -f /proc/cpuinfo ]; then
        grep -c ^processor /proc/cpuinfo
    else
        sysctl -n hw.ncpu 2>/dev/null || echo "4"
    fi
}

main() {
    echo "========================================"
    echo "maxprocs E2E Test Suite"
    echo "========================================"
    echo

    # Check Docker is available
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed or not in PATH"
        exit 1
    fi

    # Get host CPU count for unlimited test
    HOST_CPUS=$(get_host_cpus)
    log_info "Host CPU count: $HOST_CPUS"
    echo

    # Test cases
    # Format: run_test "name" "cpu_limit" "expected_count" "expected_limited" "expected_version"

    # Test 1: 1 CPU limit
    run_test "1 CPU limit" "1" "1" "true"

    # Test 2: 2 CPU limit
    run_test "2 CPU limit" "2" "2" "true"

    # Test 3: 4 CPU limit
    run_test "4 CPU limit" "4" "4" "true"

    # Test 4: Fractional CPU (1.5 -> floor to 1)
    run_test "1.5 CPU limit (fractional)" "1.5" "1" "true"

    # Test 5: Fractional CPU (2.5 -> floor to 2)
    run_test "2.5 CPU limit (fractional)" "2.5" "2" "true"

    # Test 6: Fractional CPU (0.5 -> minimum 1)
    run_test "0.5 CPU limit (minimum)" "0.5" "1" "true"

    # Test 7: No CPU limit (unlimited) - should return host CPU count
    # Note: Without --cpus, Docker may still apply cgroup with "max" value
    run_test "No CPU limit" "" "$HOST_CPUS" "false"

    # Print summary
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo -e "Passed: ${GREEN}$passed${NC}"
    echo -e "Failed: ${RED}$failed${NC}"
    echo

    if [ $failed -gt 0 ]; then
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main "$@"
