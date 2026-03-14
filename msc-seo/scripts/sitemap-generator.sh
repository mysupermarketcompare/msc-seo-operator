#!/bin/bash

# ===============================================
# SEO Sitemap Generator
# ===============================================
# Scans all generated page JSON files, extracts
# the "url" field from each, and builds a valid
# sitemap.xml for Google discovery.
#
# Runs after page generation and before git push
# so the updated sitemap is always deployed.
# ===============================================

SITE="$HOME/MSCINSURANCE-1"
PAGES="$SITE/src/data/pages"
SITEMAP="$SITE/public/sitemap.xml"
BASE_URL="https://mysupermarketcompare.com"

echo "---------------------------------------"
echo "Generating sitemap..."

# Ensure output directory exists
mkdir -p "$SITE/public"

# -----------------------------------------------
# Collect valid URLs from all page JSON files.
# Extract the "url" field via grep + sed (no jq
# dependency required).
# Uses an associative-style dedup via sort -u.
# -----------------------------------------------
URLS=""
PAGE_COUNT=0

for json_file in "$PAGES"/*.json; do
  # Skip if no JSON files exist (glob didn't expand)
  if [ ! -f "$json_file" ]; then
    continue
  fi

  # Extract the url value: match "url": "/some-path"
  url=$(grep -m1 '"url"' "$json_file" | sed 's/.*"url"[[:space:]]*:[[:space:]]*"//; s/".*//')

  # Skip empty URLs
  if [ -z "$url" ]; then
    continue
  fi

  # Safety: only accept URLs starting with /
  if [[ "$url" != /* ]]; then
    continue
  fi

  # Safety: skip URLs containing spaces (malformed)
  if [[ "$url" == *" "* ]]; then
    continue
  fi

  URLS="$URLS"$'\n'"$url"
  PAGE_COUNT=$((PAGE_COUNT + 1))
done

# Deduplicate URLs (sort -u removes exact duplicates)
URLS=$(echo "$URLS" | sort -u | sed '/^$/d')

# Count unique URLs after dedup
UNIQUE_COUNT=$(echo "$URLS" | wc -l | tr -d ' ')

echo "Found $PAGE_COUNT SEO pages ($UNIQUE_COUNT unique URLs)"

# -----------------------------------------------
# Build the sitemap XML.
# Overwrites the previous sitemap completely so
# removed pages don't persist as stale entries.
# -----------------------------------------------
echo "Writing sitemap.xml..."

cat > "$SITEMAP" <<'HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
HEADER

# Add static discovery page
cat >> "$SITEMAP" <<EOF
  <url>
    <loc>${BASE_URL}/latest-comparisons</loc>
    <changefreq>daily</changefreq>
    <priority>0.6</priority>
  </url>
EOF

# Add each URL as a <url> entry
while IFS= read -r url; do
  # Skip any remaining empty lines
  if [ -z "$url" ]; then
    continue
  fi

  cat >> "$SITEMAP" <<EOF
  <url>
    <loc>${BASE_URL}${url}</loc>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>
EOF
done <<< "$URLS"

# Close the urlset
echo "</urlset>" >> "$SITEMAP"

echo "Sitemap written to: $SITEMAP"
echo "Sitemap generation complete."
echo "---------------------------------------"
