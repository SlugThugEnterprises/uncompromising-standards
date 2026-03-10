#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKERS_DIR="$SCRIPT_DIR/../checkers"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local name="$1"
    local expected_rc="$2"
    local checker="$3"
    local test_file="$4"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  [$name] ... "

    local actual_rc=0
    "$checker" "$test_file" >/dev/null 2>&1 || actual_rc=$?

    if [[ "$actual_rc" -eq "$expected_rc" ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC} (expected $expected_rc, got $actual_rc)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "Testing Rust Checker"
run_test "rust_pass.rs PASS" 0 "$CHECKERS_DIR/rs.sh" "$SCRIPT_DIR/rust_pass.rs"
run_test "rust_fail_unsafe.rs FAIL" 1 "$CHECKERS_DIR/rs.sh" "$SCRIPT_DIR/rust_fail_unsafe.rs"
run_test "rust_fail_todo.rs FAIL" 1 "$CHECKERS_DIR/rs.sh" "$SCRIPT_DIR/rust_fail_todo.rs"

echo ""
echo "Testing Python Checker"
run_test "py_pass.py PASS" 0 "$CHECKERS_DIR/py.sh" "$SCRIPT_DIR/py_pass.py"
run_test "py_fail_notype.py FAIL" 1 "$CHECKERS_DIR/py.sh" "$SCRIPT_DIR/py_fail_notype.py"

echo ""
echo "Testing Bash Checker"
run_test "bash_pass.sh PASS" 0 "$CHECKERS_DIR/sh.sh" "$SCRIPT_DIR/bash_pass.sh"
run_test "bash_fail.sh FAIL" 1 "$CHECKERS_DIR/sh.sh" "$SCRIPT_DIR/bash_fail.sh"

echo ""
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed (total: $TESTS_RUN)"
[[ "$TESTS_FAILED" -eq 0 ]] && exit 0 || exit 1
