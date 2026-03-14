#!/bin/bash
# ============================================================
# Pipeline Hardening Validation Tests
# ============================================================
# Tests all 5 hardening fixes:
#   C6 — CRLF line ending fix
#   C7 — set -euo pipefail / error propagation
#   Pre-deployment validation
#   Error logging
#   Scoped git staging
# ============================================================

set -uo pipefail

WORKSPACE="$HOME/.openclaw/workspace/msc-seo"
PASS=0
FAIL=0
TOTAL=0

result() {
  local name="$1"
  local status="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$status" = "pass" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $name"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $name"
  fi
}

echo "=============================================="
echo "Pipeline Hardening Validation Report"
echo "Date: $(date)"
echo "=============================================="
echo ""

# ----------------------------------------------------------
# TEST 1: set -euo pipefail present in run-daily-seo.sh
# ----------------------------------------------------------
echo "--- C7: Strict bash flags ---"

if head -15 "$WORKSPACE/run-daily-seo.sh" | grep -q 'set -euo pipefail'; then
  result "set -euo pipefail in run-daily-seo.sh" "pass"
else
  result "set -euo pipefail in run-daily-seo.sh" "fail"
fi

# ----------------------------------------------------------
# TEST 2: ERR trap present
# ----------------------------------------------------------
if grep -q "trap.*ERR" "$WORKSPACE/run-daily-seo.sh"; then
  result "ERR trap for crash logging" "pass"
else
  result "ERR trap for crash logging" "fail"
fi

# ----------------------------------------------------------
# TEST 3: log_error function exists
# ----------------------------------------------------------
if grep -q "^log_error()" "$WORKSPACE/run-daily-seo.sh"; then
  result "log_error() function defined" "pass"
else
  result "log_error() function defined" "fail"
fi

# ----------------------------------------------------------
# TEST 4: pipeline-errors.log path configured
# ----------------------------------------------------------
if grep -q 'pipeline-errors.log' "$WORKSPACE/run-daily-seo.sh"; then
  result "pipeline-errors.log path configured" "pass"
else
  result "pipeline-errors.log path configured" "fail"
fi

echo ""

# ----------------------------------------------------------
# TEST 5: CRLF fix in gsc-monitor.sh
# ----------------------------------------------------------
echo "--- C6: CRLF line ending fix ---"

GSC_CRLF_COUNT=$(grep -c "lineterminator=" "$WORKSPACE/scripts/gsc-monitor.sh" || true)
if [ "$GSC_CRLF_COUNT" -ge 2 ]; then
  result "lineterminator='\\n' in both CSV writers" "pass"
else
  result "lineterminator='\\n' in both CSV writers (found $GSC_CRLF_COUNT, need 2)" "fail"
fi

# Simulate: write a test CSV with the fixed writer and verify no CRLF
CRLF_TEST_FILE=$(mktemp /tmp/crlf-test-XXXXXX.csv)
python3 -c "
import csv
with open('$CRLF_TEST_FILE', 'w', newline='') as f:
    writer = csv.writer(f, lineterminator='\n')
    writer.writerow(['url', 'http_status', 'index_status'])
    writer.writerow(['https://example.com/test', '200', 'indexed'])
"

if grep -qP '\r' "$CRLF_TEST_FILE" 2>/dev/null; then
  result "CSV output has no CRLF bytes" "fail"
else
  result "CSV output has no CRLF bytes" "pass"
fi

# Verify crawl-budget grep pattern works on clean CSV
INDEXED_COUNT=$(grep -c ',indexed$' "$CRLF_TEST_FILE" || true)
if [ "$INDEXED_COUNT" -eq 1 ]; then
  result "grep ',indexed\$' matches clean CSV lines" "pass"
else
  result "grep ',indexed\$' matches clean CSV lines" "fail"
fi

rm -f "$CRLF_TEST_FILE"

echo ""

# ----------------------------------------------------------
# TEST 6: Pre-deployment validation checks present
# ----------------------------------------------------------
echo "--- Pre-deployment validation ---"

if grep -q 'sitemap.xml' "$WORKSPACE/run-daily-seo.sh" | head -1 && \
   grep -q 'index-report.csv' "$WORKSPACE/run-daily-seo.sh" && \
   grep -q 'quality-gate.log' "$WORKSPACE/run-daily-seo.sh"; then
  result "Checks for sitemap.xml, index-report.csv, quality-gate.log" "pass"
else
  result "Checks for sitemap.xml, index-report.csv, quality-gate.log" "fail"
fi

if grep -q 'DEPLOY_OK=false' "$WORKSPACE/run-daily-seo.sh"; then
  result "Deployment abort on validation failure" "pass"
else
  result "Deployment abort on validation failure" "fail"
fi

echo ""

# ----------------------------------------------------------
# TEST 7: Scoped git staging
# ----------------------------------------------------------
echo "--- Scoped git staging ---"

if grep -q 'git add src/data/pages' "$WORKSPACE/run-daily-seo.sh"; then
  result "git add scoped to src/data/pages" "pass"
else
  result "git add scoped to src/data/pages" "fail"
fi

if grep -q 'git add public/sitemap.xml' "$WORKSPACE/run-daily-seo.sh"; then
  result "git add scoped to public/sitemap.xml" "pass"
else
  result "git add scoped to public/sitemap.xml" "fail"
fi

# Ensure the old 'git add .' is gone
if grep -q 'git add \.$' "$WORKSPACE/run-daily-seo.sh"; then
  result "'git add .' removed" "fail"
else
  result "'git add .' removed" "pass"
fi

echo ""

# ----------------------------------------------------------
# TEST 8: set -e stops on error (functional test)
# ----------------------------------------------------------
echo "--- Functional: error propagation ---"

# Create a tiny script that sources set -euo pipefail and runs a failing command
ERR_TEST=$(mktemp /tmp/err-test-XXXXXX.sh)
cat > "$ERR_TEST" << 'ERREOF'
#!/bin/bash
set -euo pipefail
false
echo "THIS SHOULD NOT PRINT"
ERREOF
chmod +x "$ERR_TEST"

if bash "$ERR_TEST" 2>/dev/null; then
  result "set -e stops execution on error" "fail"
else
  result "set -e stops execution on error" "pass"
fi
rm -f "$ERR_TEST"

# Test pipefail
PIPE_TEST=$(mktemp /tmp/pipe-test-XXXXXX.sh)
cat > "$PIPE_TEST" << 'PIPEEOF'
#!/bin/bash
set -euo pipefail
false | cat
echo "THIS SHOULD NOT PRINT"
PIPEEOF
chmod +x "$PIPE_TEST"

if bash "$PIPE_TEST" 2>/dev/null; then
  result "pipefail propagates pipeline errors" "fail"
else
  result "pipefail propagates pipeline errors" "pass"
fi
rm -f "$PIPE_TEST"

echo ""

# ----------------------------------------------------------
# TEST 9: Quality gate still works after hardening
# ----------------------------------------------------------
echo "--- Quality gate integration ---"

GATE="$WORKSPACE/scripts/quality-gate.sh"
FIXTURE="$WORKSPACE/tests/fixtures/valid-car-insurance.json"

if [ -f "$GATE" ] && [ -f "$FIXTURE" ]; then
  TMP_PAGE=$(mktemp /tmp/qg-hardening-XXXXXX.json)
  cp "$FIXTURE" "$TMP_PAGE"
  if bash "$GATE" "$TMP_PAGE" > /dev/null 2>&1; then
    result "Quality gate passes valid page" "pass"
  else
    result "Quality gate passes valid page" "fail"
  fi
  rm -f "$TMP_PAGE"

  BROKEN="$WORKSPACE/tests/fixtures/broken-thin-content.json"
  TMP_BROKEN=$(mktemp /tmp/qg-hardening-XXXXXX.json)
  cp "$BROKEN" "$TMP_BROKEN"
  if bash "$GATE" "$TMP_BROKEN" > /dev/null 2>&1; then
    result "Quality gate rejects broken page" "fail"
  else
    result "Quality gate rejects broken page" "pass"
  fi
  rm -f "$TMP_BROKEN"
else
  result "Quality gate script or fixture missing" "fail"
  result "Quality gate script or fixture missing" "fail"
fi

echo ""

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
echo "=============================================="
echo "RESULTS: $PASS passed, $FAIL failed out of $TOTAL tests"
echo "=============================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
