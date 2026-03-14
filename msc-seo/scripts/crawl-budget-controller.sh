#!/bin/bash

# ===============================================
# Crawl Budget Controller
# ===============================================
# Dynamically adjusts the number of new pages to
# generate based on Google indexing performance.
#
# Reads the index report from index-monitor.sh,
# computes the indexed/total ratio, and outputs
# a page budget number.
#
# Indexing ratio → budget:
#   < 30%  → 5 pages   (slow down, Google is behind)
#   30–60% → 15 pages  (steady growth)
#   60–80% → 30 pages  (accelerate)
#   > 80%  → 50 pages  (full speed)
#
# If no report exists (first run), defaults to 15.
#
# IMPORTANT: Only the final budget number is printed
# to stdout so it can be captured via $().
# All logging goes to stderr.
# ===============================================

WORKSPACE="$HOME/.openclaw/workspace/msc-seo"
REPORT="$WORKSPACE/data/index-report.csv"

# Absolute safety bounds
MIN_BUDGET=5
MAX_BUDGET=50
DEFAULT_BUDGET=15

# -----------------------------------------------
# If no index report exists yet (first run or
# monitor hasn't run), use the default budget.
# -----------------------------------------------
if [ ! -f "$REPORT" ]; then
  echo "Crawl budget controller: no index report found, using default ($DEFAULT_BUDGET)" >&2
  echo "$DEFAULT_BUDGET"
  exit 0
fi

# -----------------------------------------------
# Count indexed and not_indexed pages from the
# report CSV. The third column contains the
# index status: "indexed", "not_indexed", or "unknown".
# -----------------------------------------------
INDEXED=$(grep -c ',indexed$' "$REPORT" 2>/dev/null)
INDEXED=${INDEXED:-0}
NOT_INDEXED=$(grep -c ',not_indexed$' "$REPORT" 2>/dev/null)
NOT_INDEXED=${NOT_INDEXED:-0}
TOTAL=$((INDEXED + NOT_INDEXED))

# -----------------------------------------------
# If no valid entries in report (all timeouts/errors
# or empty report), use default budget.
# -----------------------------------------------
if [ "$TOTAL" -eq 0 ]; then
  echo "Crawl budget controller: no indexable pages in report, using default ($DEFAULT_BUDGET)" >&2
  echo "$DEFAULT_BUDGET"
  exit 0
fi

# -----------------------------------------------
# Compute indexing ratio as a percentage (integer).
# Bash doesn't do floating point, so multiply by
# 100 first to get a whole-number percentage.
# -----------------------------------------------
RATIO=$((INDEXED * 100 / TOTAL))

# -----------------------------------------------
# Determine budget based on indexing ratio tiers.
# -----------------------------------------------
if [ "$RATIO" -lt 30 ]; then
  BUDGET=5
elif [ "$RATIO" -lt 60 ]; then
  BUDGET=15
elif [ "$RATIO" -lt 80 ]; then
  BUDGET=30
else
  BUDGET=50
fi

# -----------------------------------------------
# Clamp to safety bounds (defensive check).
# -----------------------------------------------
if [ "$BUDGET" -lt "$MIN_BUDGET" ]; then
  BUDGET=$MIN_BUDGET
fi
if [ "$BUDGET" -gt "$MAX_BUDGET" ]; then
  BUDGET=$MAX_BUDGET
fi

# -----------------------------------------------
# Log summary to stderr (visible in console but
# not captured by command substitution).
# -----------------------------------------------
echo "---------------------------------------" >&2
echo "Crawl budget controller" >&2
echo "Indexed pages:    $INDEXED" >&2
echo "Not indexed pages: $NOT_INDEXED" >&2
echo "Index ratio:      ${RATIO}%" >&2
echo "New crawl budget: $BUDGET pages" >&2
echo "---------------------------------------" >&2

# -----------------------------------------------
# Output ONLY the budget number to stdout.
# This is captured by: CRAWL_BUDGET=$(bash script)
# -----------------------------------------------
echo "$BUDGET"
