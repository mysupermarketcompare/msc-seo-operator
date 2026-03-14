#!/bin/bash
# ============================================================
# Test runner for quality-gate.sh
# Tests 3 valid pages and 3 broken pages, produces a report.
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(dirname "$SCRIPT_DIR")"
GATE="$WORKSPACE/scripts/quality-gate.sh"
FIXTURES="$SCRIPT_DIR/fixtures"
REPORT="$WORKSPACE/reports/quality-gate-test-report.txt"

PASS=0
FAIL=0
ERRORS=()

echo "=============================================="
echo "Quality Gate Test Suite"
echo "Date: $(date)"
echo "=============================================="
echo ""

run_test() {
  local description="$1"
  local fixture="$2"
  local expect_pass="$3"  # "pass" or "fail"

  # Copy fixture to a temp file so deletion doesn't destroy the original
  local tmpfile
  tmpfile=$(mktemp /tmp/qg-test-XXXXXX.json)
  cp "$fixture" "$tmpfile"

  echo "--- Test: $description ---"
  echo "  File: $(basename "$fixture")"
  echo "  Expected: $expect_pass"

  local output
  output=$(bash "$GATE" "$tmpfile" 2>&1)
  local exit_code=$?

  echo "  Output: $output"

  if [ "$expect_pass" = "pass" ] && [ "$exit_code" -eq 0 ]; then
    echo "  Result: CORRECT (passed as expected)"
    PASS=$((PASS + 1))
  elif [ "$expect_pass" = "fail" ] && [ "$exit_code" -ne 0 ]; then
    echo "  Result: CORRECT (failed as expected)"
    PASS=$((PASS + 1))
  else
    echo "  Result: INCORRECT (expected $expect_pass, got exit code $exit_code)"
    ERRORS+=("$description")
    FAIL=$((FAIL + 1))
  fi

  # Clean up temp file if it still exists
  rm -f "$tmpfile"
  echo ""
}

# --- Valid pages (should pass) ---
run_test "Valid car insurance page" "$FIXTURES/valid-car-insurance.json" "pass"
run_test "Valid pet insurance page" "$FIXTURES/valid-pet-insurance.json" "pass"
run_test "Valid home insurance page" "$FIXTURES/valid-home-insurance.json" "pass"

# --- Broken pages (should fail) ---
run_test "Invalid JSON syntax" "$FIXTURES/broken-invalid-json.json" "fail"
run_test "Thin content (low word count, few sections, few FAQs)" "$FIXTURES/broken-thin-content.json" "fail"
run_test "Vertical contamination (pet page with vehicle/driver/mileage)" "$FIXTURES/broken-contaminated-pet.json" "fail"

# --- Summary ---
echo "=============================================="
echo "RESULTS: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests"
echo "=============================================="

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "FAILING TESTS:"
  for e in "${ERRORS[@]}"; do
    echo "  - $e"
  done
fi

# Write report file
mkdir -p "$(dirname "$REPORT")"
{
  echo "Quality Gate Test Report"
  echo "Date: $(date)"
  echo "========================"
  echo ""
  echo "Tests run: $((PASS + FAIL))"
  echo "Passed: $PASS"
  echo "Failed: $FAIL"
  echo ""
  if [ ${#ERRORS[@]} -gt 0 ]; then
    echo "Failing tests:"
    for e in "${ERRORS[@]}"; do
      echo "  - $e"
    done
  else
    echo "All tests passed."
  fi
} > "$REPORT"

echo ""
echo "Report written to: $REPORT"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
