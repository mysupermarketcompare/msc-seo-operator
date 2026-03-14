#!/bin/bash

# ===============================================
# Google Index Monitoring Engine
# ===============================================
# Scans all generated SEO page JSON files, checks
# whether each page:
#   1. Returns HTTP 200 (page is live)
#   2. Appears in Google search results (indexed)
#
# Outputs a CSV report for tracking index health
# over time. Runs after page generation/linking
# and before git push.
# ===============================================

SITE="$HOME/MSCINSURANCE-1"
PAGES="$SITE/src/data/pages"
WORKSPACE="$HOME/.openclaw/workspace/msc-seo"
REPORT="$WORKSPACE/data/index-report.csv"
BASE_URL="https://mysupermarketcompare.com"

# Maximum pages to check per run to avoid Google throttling.
# 50 checks × 1s delay ≈ ~1 minute of requests.
MAX_INDEX_CHECKS=50

# Counters for summary
COUNT_INDEXED=0
COUNT_NOT_INDEXED=0
COUNT_HTTP_ERROR=0
COUNT_TIMEOUT=0
CHECKED=0

echo "======================================="
echo "Running index monitoring engine..."
echo "Time: $(date)"
echo "======================================="

# -----------------------------------------------
# Step 1: Collect URLs from all page JSON files.
# Extract the "url" field via grep, same approach
# used by the sitemap generator.
# -----------------------------------------------
echo "Scanning page definitions..."

URLS=()
for json_file in "$PAGES"/*.json; do
  if [ ! -f "$json_file" ]; then
    continue
  fi

  url=$(grep -m1 '"url"' "$json_file" | sed 's/.*"url"[[:space:]]*:[[:space:]]*"//; s/".*//')

  # Skip empty or malformed URLs
  if [ -z "$url" ]; then
    continue
  fi
  if [[ "$url" != /* ]]; then
    continue
  fi
  if [[ "$url" == *" "* ]]; then
    continue
  fi

  URLS+=("$url")
done

# Deduplicate URLs (preserve array form)
UNIQUE_URLS=($(printf '%s\n' "${URLS[@]}" | sort -u))

echo "Found ${#UNIQUE_URLS[@]} unique page URLs"

# -----------------------------------------------
# Step 2: Write CSV header.
# Overwrites previous report so each run produces
# a fresh snapshot of index health.
# -----------------------------------------------
mkdir -p "$(dirname "$REPORT")"
echo "url,http_status,index_status" > "$REPORT"

# -----------------------------------------------
# Step 3: Check each page.
# For each URL:
#   a) HTTP HEAD request to verify the page is live
#   b) Google site: query to check indexing
# -----------------------------------------------
echo "Checking page status..."

for url_path in "${UNIQUE_URLS[@]}"; do

  # Enforce per-run check limit
  if [ "$CHECKED" -ge "$MAX_INDEX_CHECKS" ]; then
    echo "Check limit reached ($MAX_INDEX_CHECKS). Stopping."
    break
  fi

  full_url="${BASE_URL}${url_path}"

  # ----- Step 3a: HTTP status check -----
  # Use curl HEAD request with 10s timeout.
  # Extract the HTTP status code from the response.
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -I "$full_url" 2>/dev/null)

  if [ "$http_code" = "000" ]; then
    # Timeout or connection failure
    echo "  TIMEOUT: $full_url"
    echo "$full_url,timeout,unknown" >> "$REPORT"
    COUNT_TIMEOUT=$((COUNT_TIMEOUT + 1))
    CHECKED=$((CHECKED + 1))
    sleep 1
    continue
  fi

  if [ "$http_code" != "200" ]; then
    # Page returned a non-200 status (404, 500, etc.)
    echo "  HTTP $http_code: $full_url"
    echo "$full_url,$http_code,unknown" >> "$REPORT"
    COUNT_HTTP_ERROR=$((COUNT_HTTP_ERROR + 1))
    CHECKED=$((CHECKED + 1))
    sleep 1
    continue
  fi

  # ----- Step 3b: Google index check -----
  # Query Google with site: operator to see if the
  # specific URL appears in their index.
  # Use a realistic User-Agent to avoid instant blocks.
  search_query="site:mysupermarketcompare.com${url_path}"
  encoded_query=$(printf '%s' "$search_query" | sed 's/ /+/g; s/:/%3A/g; s/\//%2F/g')

  google_response=$(curl -s --max-time 10 \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    "https://www.google.com/search?q=${encoded_query}" 2>/dev/null)

  # Check if the page URL appears in the Google response HTML.
  # If Google has indexed the page, the URL will appear in
  # the search results markup.
  if echo "$google_response" | grep -qi "mysupermarketcompare.com${url_path}"; then
    echo "  INDEXED: $full_url"
    echo "$full_url,200,indexed" >> "$REPORT"
    COUNT_INDEXED=$((COUNT_INDEXED + 1))
  else
    echo "  NOT INDEXED: $full_url"
    echo "$full_url,200,not_indexed" >> "$REPORT"
    COUNT_NOT_INDEXED=$((COUNT_NOT_INDEXED + 1))
  fi

  CHECKED=$((CHECKED + 1))

  # Rate limit: 1 second between requests to avoid
  # being blocked by Google
  sleep 1

done

# -----------------------------------------------
# Step 4: Print summary
# -----------------------------------------------
echo "---------------------------------------"
echo "Index monitoring complete"
echo "Pages checked:    $CHECKED"
echo "Indexed:          $COUNT_INDEXED"
echo "Not indexed:      $COUNT_NOT_INDEXED"
echo "HTTP errors:      $COUNT_HTTP_ERROR"
echo "Timeouts:         $COUNT_TIMEOUT"
echo "Report saved to:  $REPORT"
echo "======================================="
