#!/bin/bash

set -a
if [ -f ".env" ]; then
  source .env
fi
set +a

set -euo pipefail

"$HOME/.openclaw/workspace/msc-seo/scripts/telegram-notify.sh" "MSC SEO Operator started — $(date)" || true

echo "======================================="
echo "Starting MySupermarketCompare SEO operator"
echo "Time: $(date)"
echo "======================================="

WORKSPACE="$HOME/.openclaw/workspace/msc-seo"
SITE="$HOME/MSCINSURANCE-1"

# -----------------------------------------------
# Error logging infrastructure
# -----------------------------------------------
mkdir -p "$WORKSPACE/reports"
ERROR_LOG="$WORKSPACE/reports/pipeline-errors.log"

log_error() {
  local step="$1"
  local msg="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$step] $msg" >> "$ERROR_LOG"
  echo "ERROR [$step]: $msg"
}

ALERT_LOG="$WORKSPACE/reports/alerts.log"

pipeline_alert() {
  local line="$1"
  local code="$2"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M')

  local alert
  alert="[ALERT] MSC SEO Operator failed
Time: $ts
Line: $line
Exit code: $code"

  # stdout
  echo ""
  echo "======================================="
  echo "$alert"
  echo "======================================="

  # alerts.log
  echo "$alert" >> "$ALERT_LOG"
  echo "---" >> "$ALERT_LOG"
}

# Trap unexpected failures so they hit the error log and alert log
trap 'TRAP_CODE=$?; log_error "UNEXPECTED" "Pipeline crashed at line $LINENO (exit code $TRAP_CODE)"; pipeline_alert "$LINENO" "$TRAP_CODE"; "$HOME/.openclaw/workspace/msc-seo/scripts/telegram-notify.sh" "MSC SEO Operator ERROR — pipeline crashed at line $LINENO" || true; exit 1' ERR

KEYWORDS="$WORKSPACE/data/target-keywords.csv"
PAGES="$SITE/src/data/pages"

CRAWLER="$WORKSPACE/scripts/competitor-crawler.sh"
EXPANDER="$WORKSPACE/scripts/autocomplete-expander.sh"
CLUSTER_EXP="$WORKSPACE/scripts/cluster-expander.sh"
SITEMAP_GEN="$WORKSPACE/scripts/sitemap-generator.sh"
LINKER="$WORKSPACE/scripts/internal-linker.sh"
HUB_GEN="$WORKSPACE/scripts/hub-page-generator.sh"
INDEX_MON="$WORKSPACE/scripts/gsc-monitor.sh"
BUDGET_CTL="$WORKSPACE/scripts/crawl-budget-controller.sh"
QUALITY_GATE="$WORKSPACE/scripts/quality-gate.sh"

# Default page limit — overridden by crawl budget controller if report exists
MAX_NEW_PAGES=15

# -----------------------------------------------
# Helper: safe_slug
# Generates a URL-safe slug from any input string.
# - lowercases the input
# - replaces spaces with hyphens
# - strips all characters except a-z, 0-9, and hyphens
# - collapses consecutive hyphens into one
# - trims leading/trailing hyphens
# -----------------------------------------------
safe_slug() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr ' ' '-' \
    | sed 's/[^a-z0-9-]//g' \
    | sed 's/--*/-/g' \
    | sed 's/^-//;s/-$//'
}

# -----------------------------------------------
# Helper: is_valid_keyword
# Returns 0 (true) if the keyword is acceptable for
# generating a comparison page. Returns 1 (false) if
# the keyword is junk, informational, or malformed.
#
# Rejection rules:
#   - contains commas (malformed CSV or compound keyword)
#   - more than 7 words (too long / likely informational)
#   - contains informational terms: guide, tips, checklist,
#     rules, calculator (not comparison intent)
# -----------------------------------------------
is_valid_keyword() {
  local kw="$1"

  # Reject keywords containing commas (malformed data)
  if [[ "$kw" == *","* ]]; then
    return 1
  fi

  # Reject keywords with more than 7 words
  local word_count
  word_count=$(echo "$kw" | wc -w | tr -d ' ')
  if [ "$word_count" -gt 7 ]; then
    return 1
  fi

  # Reject informational keywords (case-insensitive check)
  local kw_lower
  kw_lower=$(echo "$kw" | tr '[:upper:]' '[:lower:]')
  for blocked in guide tips checklist rules calculator; do
    if [[ "$kw_lower" == *"$blocked"* ]]; then
      return 1
    fi
  done

  return 0
}

# -----------------------------------------------
# Helper: title_case
# Converts a string to Title Case for display.
# - capitalises the first letter of each word
# - preserves numbers and short words
# -----------------------------------------------
title_case() {
  echo "$1" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
}

# -----------------------------------------------
# Helper: sanitize_url
# Ensures the URL pattern is well-formed:
#   - starts with /
#   - no spaces (replaced with hyphens)
#   - no commas or fragment identifiers
#   - lowercased
# -----------------------------------------------
sanitize_url() {
  local url="$1"

  # Remove commas and fragment identifiers
  url=$(echo "$url" | sed 's/,//g; s/#[^/]*//g')

  # Replace spaces with hyphens
  url=$(echo "$url" | tr ' ' '-')

  # Lowercase
  url=$(echo "$url" | tr '[:upper:]' '[:lower:]')

  # Collapse double hyphens
  url=$(echo "$url" | sed 's/--*/-/g')

  # Ensure URL starts with /
  if [[ "$url" != /* ]]; then
    url="/$url"
  fi

  echo "$url"
}

# -----------------------------------------------
# Helper: validate_page_quality
# SEO quality gate — delegates to external script
# scripts/quality-gate.sh for full validation:
#   1. Word count >= 700
#   2. Sections >= 6
#   3. FAQ items >= 5
#   4. Required fields present
#   5. Valid URL with approved vertical
#   6. CTA endpoint present
#   7. Vertical contamination check
#
# The external script deletes the file on failure.
#
# Usage: validate_page_quality "/path/to/page.json"
# Returns: 0 if page passes, 1 if rejected
# -----------------------------------------------
validate_page_quality() {
  local file="$1"

  if [ ! -f "$file" ]; then
    echo "  Quality gate: file not found — $file"
    return 1
  fi

  if [ -f "$QUALITY_GATE" ]; then
    bash "$QUALITY_GATE" "$file"
  else
    echo "  Quality gate script not found at $QUALITY_GATE"
    return 1
  fi
}

# -----------------------------------------------
# Step 1: Run Google Autocomplete keyword expander
# -----------------------------------------------
echo "Running autocomplete keyword expansion..."

if [ -f "$EXPANDER" ]; then
  bash "$EXPANDER"
else
  echo "Autocomplete expander not found at $EXPANDER"
fi

# -----------------------------------------------
# Step 2: Run cluster keyword expansion
# -----------------------------------------------
echo "Running cluster keyword expansion..."

if [ -f "$CLUSTER_EXP" ]; then
  bash "$CLUSTER_EXP"
else
  echo "Cluster expander not found at $CLUSTER_EXP"
fi

# -----------------------------------------------
# Step 3: Run competitor intelligence crawler
# -----------------------------------------------
echo "Running competitor intelligence..."

if [ -f "$CRAWLER" ]; then
  bash "$CRAWLER"
else
  echo "Crawler script not found at $CRAWLER"
fi

# -----------------------------------------------
# Step 4: Compute dynamic crawl budget
# -----------------------------------------------
# The controller reads the previous run's index report
# and adjusts MAX_NEW_PAGES based on indexing ratio.
# Output goes to stdout (just a number), logs to stderr.
echo "Computing crawl budget..."

if [ -f "$BUDGET_CTL" ]; then
  CRAWL_BUDGET=$(bash "$BUDGET_CTL") || true
  if [ -n "${CRAWL_BUDGET:-}" ] && [ "$CRAWL_BUDGET" -gt 0 ] 2>/dev/null; then
    MAX_NEW_PAGES=$CRAWL_BUDGET
  fi
else
  echo "Budget controller not found, using default: MAX_NEW_PAGES=$MAX_NEW_PAGES"
fi

# Enforce minimum floor of 10 pages/day
if [ "$MAX_NEW_PAGES" -lt 10 ]; then
  MAX_NEW_PAGES=10
fi

echo "Crawl budget set: MAX_NEW_PAGES=$MAX_NEW_PAGES"

# -----------------------------------------------
# Step 5: Process keywords and generate pages
# -----------------------------------------------
echo "Scanning keyword opportunities..."

if [ ! -f "$KEYWORDS" ]; then
  log_error "keyword-scan" "Keywords file not found: $KEYWORDS"
  exit 1
fi

mkdir -p "$PAGES"

NEW_PAGES=0
FAILED_PAGES=0
QUALITY_LOG="$WORKSPACE/reports/quality-gate.log"
echo "Quality gate log — $(date)" > "$QUALITY_LOG"

while IFS=',' read -r vertical keyword url_pattern
do
  # Skip empty lines
  if [ -z "$keyword" ] || [ -z "$vertical" ]; then
    continue
  fi

  # Trim whitespace from fields
  vertical=$(echo "$vertical" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  keyword=$(echo "$keyword" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  url_pattern=$(echo "$url_pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # --- Safety check: validate keyword before generating ---
  if ! is_valid_keyword "$keyword"; then
    echo "Skipping invalid keyword: $keyword"
    continue
  fi

  # --- Generate safe slug and filename with vertical prefix ---
  slug=$(safe_slug "$keyword")
  vertical_slug=$(safe_slug "$vertical")

  # Strip vertical prefix from slug to prevent double-prefixing.
  # e.g. keyword="car insurance london" → slug="car-insurance-london"
  #      vertical="car insurance"       → vertical_slug="car-insurance"
  #      Without fix: car-insurance-car-insurance-london.json (WRONG)
  #      With fix:    car-insurance-london.json (CORRECT)
  if [[ "$slug" == "${vertical_slug}-"* ]]; then
    slug="${slug#${vertical_slug}-}"
  fi

  file="$PAGES/${vertical_slug}-${slug}.json"

  # --- Skip if page already exists ---
  if [ -f "$file" ]; then
    echo "Skipping existing page: ${vertical_slug}-${slug}.json"
    continue
  fi

  # --- Enforce rate limit ---
  if [ "$NEW_PAGES" -ge "$MAX_NEW_PAGES" ]; then
    echo "Rate limit reached ($MAX_NEW_PAGES pages). Stopping generation."
    break
  fi

  # --- Sanitize the URL pattern to prevent malformed routes ---
  url_pattern=$(sanitize_url "$url_pattern")

  # --- Build display strings ---
  kw_title=$(title_case "$keyword")
  vertical_title=$(title_case "$vertical")

  echo "Generating page: $keyword (${vertical_slug}-${slug}.json)"

  # --- Generate page JSON using vertical-specific template ---
  TEMPLATE_SCRIPT="$WORKSPACE/scripts/page-templates.sh"
  if ! bash "$TEMPLATE_SCRIPT" "$vertical_slug" "$keyword" "$url_pattern" "$kw_title" "$vertical_title" > "$file"; then
    log_error "page-generation" "Template script failed for $keyword"
    rm -f "$file"
    FAILED_PAGES=$((FAILED_PAGES + 1))
    continue
  fi

  # --- Quality gate: validate before accepting ---
  if validate_page_quality "$file"; then
    echo "  Page passed quality gate: ${vertical_slug}-${slug}.json"
    echo "PASS: ${vertical_slug}-${slug}.json" >> "$QUALITY_LOG"
    NEW_PAGES=$((NEW_PAGES + 1))
  else
    log_error "quality-gate" "Rejected ${vertical_slug}-${slug}.json"
    echo "FAIL: ${vertical_slug}-${slug}.json — deleted" >> "$QUALITY_LOG"
    FAILED_PAGES=$((FAILED_PAGES + 1))
  fi

done < <(tail -n +2 "$KEYWORDS")

# -----------------------------------------------
# Step 5.5: Formatting cleaner — remove em dashes
# -----------------------------------------------
echo "Running formatting cleaner..."

FORMATTER="$WORKSPACE/scripts/formatting-cleaner.sh"
if [ -f "$FORMATTER" ]; then
  bash "$FORMATTER"
else
  echo "Formatting cleaner not found at $FORMATTER (skipping)"
fi

# -----------------------------------------------
# Step 5.6: Metadata optimiser — titles & descriptions
# -----------------------------------------------
echo "Running metadata optimiser..."

META_OPT="$WORKSPACE/scripts/metadata-optimizer.sh"
if [ -f "$META_OPT" ]; then
  bash "$META_OPT"
else
  echo "Metadata optimiser not found at $META_OPT (skipping)"
fi

# -----------------------------------------------
# Step 5.7: Ranking optimizer — title & content boost
# -----------------------------------------------
echo "Running ranking optimizer..."

RANK_OPT="$WORKSPACE/scripts/ranking-optimizer.sh"
if [ -f "$RANK_OPT" ]; then
  bash "$RANK_OPT"
else
  echo "Ranking optimizer not found at $RANK_OPT (skipping)"
fi

# -----------------------------------------------
# Step 6: Rebuild sitemap.xml with all SEO pages
# -----------------------------------------------
echo "Rebuilding sitemap..."

if [ -f "$SITEMAP_GEN" ]; then
  bash "$SITEMAP_GEN"
else
  echo "Sitemap generator not found at $SITEMAP_GEN"
fi

# -----------------------------------------------
# Step 6.5: Inject cluster page metadata
# -----------------------------------------------
echo "Running cluster page generator..."

CLUSTER_GEN="$WORKSPACE/scripts/cluster-generator.sh"
if [ -f "$CLUSTER_GEN" ]; then
  bash "$CLUSTER_GEN"
else
  echo "Cluster generator not found at $CLUSTER_GEN (skipping)"
fi

# -----------------------------------------------
# Step 7: Generate internal links between pages
# -----------------------------------------------
echo "Running internal linking engine..."

if [ -f "$LINKER" ]; then
  bash "$LINKER"
else
  echo "Internal linker not found at $LINKER"
fi

# -----------------------------------------------
# Step 7.5: Ranking link boost — inject inbound links
# -----------------------------------------------
echo "Running ranking link boost..."

LINK_BOOST="$WORKSPACE/scripts/ranking-link-boost.sh"
if [ -f "$LINK_BOOST" ]; then
  bash "$LINK_BOOST"
else
  echo "Ranking link boost not found at $LINK_BOOST (skipping)"
fi

# -----------------------------------------------
# Step 8: Generate hub pages for each vertical
# -----------------------------------------------
echo "Running hub page generator..."

if [ -f "$HUB_GEN" ]; then
  bash "$HUB_GEN"
else
  echo "Hub page generator not found at $HUB_GEN"
fi

# -----------------------------------------------
# Step 9: Check Google index status for SEO pages
# -----------------------------------------------
echo "Running index monitoring..."

if [ -f "$INDEX_MON" ]; then
  bash "$INDEX_MON"
else
  echo "Index monitor not found at $INDEX_MON"
fi

# -----------------------------------------------
# Step 10: Pre-deployment validation
# -----------------------------------------------
echo "Running pre-deployment checks..."

DEPLOY_OK=true

# Validate sitemap exists and is non-empty
SITEMAP_FILE="$SITE/public/sitemap.xml"
if [ ! -s "$SITEMAP_FILE" ]; then
  log_error "pre-deploy" "sitemap.xml missing or empty at $SITEMAP_FILE"
  DEPLOY_OK=false
fi

# Validate index report exists and is non-empty
if [ ! -s "$WORKSPACE/data/index-report.csv" ]; then
  log_error "pre-deploy" "data/index-report.csv missing or empty"
  DEPLOY_OK=false
fi

# Validate quality gate log exists and is non-empty
if [ ! -s "$QUALITY_LOG" ]; then
  log_error "pre-deploy" "reports/quality-gate.log missing or empty"
  DEPLOY_OK=false
fi

if [ "$DEPLOY_OK" = false ]; then
  log_error "pre-deploy" "Pre-deployment validation failed — aborting git publish"
  echo "---------------------------------------"
  echo "ABORTED: deployment blocked by pre-deploy checks"
  echo "New pages generated: $NEW_PAGES"
  echo "Pages rejected by quality gate: $FAILED_PAGES"
  echo "Error log: $ERROR_LOG"
  echo "======================================="
  exit 1
fi

echo "Pre-deployment checks passed."

# -----------------------------------------------
# Step 11: Publish via git push (triggers Vercel deploy)
# -----------------------------------------------
echo "Checking repo status..."

cd "$SITE"

git add src/data/pages
git add public/sitemap.xml

if git diff --cached --quiet; then
  echo "No new SEO pages found."
else
  echo "Publishing new pages..."
  git commit -m "SEO operator generated pages"
  git push
fi

# -----------------------------------------------
# Step 12: Daily run summary
# -----------------------------------------------

# Count total pages on disk
TOTAL_PAGES=$(ls -1 "$PAGES"/*.json 2>/dev/null | wc -l | tr -d ' ')

# Compute indexing ratio from index report
INDEX_REPORT="$WORKSPACE/data/index-report.csv"
if [ -f "$INDEX_REPORT" ]; then
  IDX_INDEXED=$(grep -c ',indexed$' "$INDEX_REPORT" 2>/dev/null || true)
  IDX_INDEXED=${IDX_INDEXED:-0}
  IDX_NOT=$(grep -c ',not_indexed$' "$INDEX_REPORT" 2>/dev/null || true)
  IDX_NOT=${IDX_NOT:-0}
  IDX_TOTAL=$((IDX_INDEXED + IDX_NOT))
  if [ "$IDX_TOTAL" -gt 0 ]; then
    IDX_RATIO=$((IDX_INDEXED * 100 / IDX_TOTAL))
    INDEXING_RATIO="${IDX_RATIO}% (${IDX_INDEXED}/${IDX_TOTAL})"
  else
    INDEXING_RATIO="no data"
  fi
else
  INDEXING_RATIO="no report"
fi

RUN_LOG="$WORKSPACE/reports/daily-run.log"

SUMMARY="=======================================
DAILY RUN SUMMARY
Date: $(date '+%Y-%m-%d %H:%M:%S')
=======================================
Pages generated:     $NEW_PAGES
Pages rejected:      $FAILED_PAGES
Total pages on disk: $TOTAL_PAGES
Crawl budget:        $MAX_NEW_PAGES pages/day
Indexing ratio:      $INDEXING_RATIO
Pipeline status:     SUCCESS
======================================="

echo "$SUMMARY"
echo "$SUMMARY" >> "$RUN_LOG"

# Send Telegram completion summary
NOTIFIER="$WORKSPACE/scripts/telegram-notify.sh"
TG_MESSAGE="MSC SEO Operator finished

Pages generated today: $NEW_PAGES
Total pages: $TOTAL_PAGES
Crawl budget: $MAX_NEW_PAGES
Indexed pages: ${IDX_INDEXED:-N/A}"

"$NOTIFIER" "$TG_MESSAGE" || true
