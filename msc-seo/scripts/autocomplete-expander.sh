#!/bin/bash

# ===============================================
# Google Autocomplete Keyword Expander
# ===============================================
# Reads seed keywords from target-keywords.csv,
# queries Google Autocomplete for long-tail suggestions,
# classifies each into a vertical, and appends new
# keyword opportunities back to the CSV.
#
# This runs BEFORE the competitor crawler and page
# generator in the daily SEO pipeline.
# ===============================================

WORKSPACE="$HOME/.openclaw/workspace/msc-seo"
KEYWORDS="$WORKSPACE/data/target-keywords.csv"

# Safety cap: max new keywords discovered per run
MAX_AUTOCOMPLETE_EXPANSIONS=50

# Seed limit: only query autocomplete for this many seeds per run.
# Prevents hammering Google when the CSV grows to thousands of rows.
# 40 seeds × ~6 suggestions × 0.5s delay ≈ 20 seconds of requests.
MAX_SEEDS_PER_RUN=40

# Google Autocomplete endpoint (returns JSON array via Firefox client)
AUTOCOMPLETE_URL="https://suggestqueries.google.com/complete/search?client=firefox&q="

# Counter for new discoveries this run
DISCOVERED=0

echo "======================================="
echo "Google Autocomplete Keyword Expander"
echo "Time: $(date)"
echo "======================================="

# -----------------------------------------------
# Known insurance verticals.
# A suggestion must contain one of these phrases
# to be classified and accepted.
# -----------------------------------------------
VERTICALS=(
  "car insurance"
  "home insurance"
  "van insurance"
  "motorbike insurance"
  "pet insurance"
  "travel insurance"
  "bicycle insurance"
  "breakdown cover"
)

# -----------------------------------------------
# Helper: safe_slug
# Generates a URL-safe slug from any input string.
# - lowercases
# - spaces → hyphens
# - strips non-alphanumeric (except hyphens)
# - collapses consecutive hyphens
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
# Helper: is_valid_suggestion
# Returns 0 (true) if the suggestion is a valid
# comparison-intent keyword. Returns 1 (false) if
# it's informational, too long, or malformed.
#
# Rejection rules:
#   - contains commas
#   - more than 8 words
#   - contains informational terms
# -----------------------------------------------
is_valid_suggestion() {
  local kw="$1"

  # Reject if contains commas
  if [[ "$kw" == *","* ]]; then
    return 1
  fi

  # Reject if more than 8 words
  local word_count
  word_count=$(echo "$kw" | wc -w | tr -d ' ')
  if [ "$word_count" -gt 8 ]; then
    return 1
  fi

  # Reject informational keywords (case-insensitive)
  local kw_lower
  kw_lower=$(echo "$kw" | tr '[:upper:]' '[:lower:]')
  for blocked in "guide" "tips" "rules" "checklist" "calculator" "how to" "what is" "why does"; do
    if [[ "$kw_lower" == *"$blocked"* ]]; then
      return 1
    fi
  done

  return 0
}

# -----------------------------------------------
# Helper: classify_vertical
# Checks if a suggestion contains a known vertical
# phrase. Echoes the vertical name if found, or
# empty string if no match.
# Checks longest phrases first to avoid false
# partial matches (e.g. "breakdown cover" before
# shorter patterns).
# -----------------------------------------------
classify_vertical() {
  local suggestion
  suggestion=$(echo "$1" | tr '[:upper:]' '[:lower:]')

  for v in "${VERTICALS[@]}"; do
    if [[ "$suggestion" == *"$v"* ]]; then
      echo "$v"
      return 0
    fi
  done

  # No vertical match — suggestion is off-topic
  echo ""
  return 1
}

# -----------------------------------------------
# Helper: build_url_pattern
# Given a vertical and full keyword, generates the
# URL pattern by:
#   1. Converting vertical to slug (e.g. "car insurance" → "car-insurance")
#   2. Removing the vertical phrase from the keyword to get the tail
#   3. Slugifying the tail
#   4. Composing /{vertical-slug}/{tail-slug}
# -----------------------------------------------
build_url_pattern() {
  local vertical="$1"
  local keyword="$2"

  local vertical_slug
  vertical_slug=$(safe_slug "$vertical")

  # Remove the vertical phrase from the keyword to get the modifier/tail
  # e.g. "car insurance young drivers black box" → "young drivers black box"
  local keyword_lower
  keyword_lower=$(echo "$keyword" | tr '[:upper:]' '[:lower:]')
  local vertical_lower
  vertical_lower=$(echo "$vertical" | tr '[:upper:]' '[:lower:]')

  local tail
  tail=$(echo "$keyword_lower" | sed "s/$vertical_lower//")
  # Trim leading/trailing whitespace
  tail=$(echo "$tail" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # If tail is empty after removing vertical, skip (bare vertical keyword)
  if [ -z "$tail" ]; then
    echo ""
    return 1
  fi

  local tail_slug
  tail_slug=$(safe_slug "$tail")

  if [ -z "$tail_slug" ]; then
    echo ""
    return 1
  fi

  echo "/$vertical_slug/$tail_slug"
  return 0
}

# -----------------------------------------------
# Helper: keyword_exists
# Checks if a keyword already exists in the CSV.
# Uses grep with fixed-string match on the keyword
# field (second column).
# Returns 0 if found (duplicate), 1 if new.
# -----------------------------------------------
keyword_exists() {
  local kw="$1"
  # Match as the second CSV field: either after first comma or on the line
  # Using grep -F for literal match to avoid regex issues
  if grep -qF ",$kw," "$KEYWORDS" 2>/dev/null; then
    return 0
  fi
  return 1
}

# -----------------------------------------------
# Helper: query_autocomplete
# Queries Google Autocomplete for a given seed phrase.
# Returns suggestions one per line.
# The Firefox client returns JSON: ["query", ["sugg1","sugg2",...]]
# We extract the suggestion array.
# -----------------------------------------------
query_autocomplete() {
  local seed="$1"

  # URL-encode the seed query (spaces → +)
  local encoded
  encoded=$(echo "$seed" | sed 's/ /+/g')

  # Fetch suggestions — silent curl, 10s timeout
  local response
  response=$(curl -s --max-time 10 "${AUTOCOMPLETE_URL}${encoded}")

  # Parse the JSON suggestion array
  # Response format: ["query",["suggestion1","suggestion2",...]]
  # Extract the array contents and split into lines
  echo "$response" \
    | sed 's/.*\["\([^]]*\)\].*/\1/' \
    | sed 's/^[^[]*\[//; s/\].*$//' \
    | tr ',' '\n' \
    | sed 's/^"//; s/"$//' \
    | sed '/^$/d'
}

# -----------------------------------------------
# Main: Extract seed keywords from CSV
# -----------------------------------------------
echo "Loading seed keywords from CSV..."

# Load only the first MAX_SEEDS_PER_RUN keywords from the CSV.
# This prevents querying Google for every row as the dataset
# grows into thousands. Seeds rotate naturally as new keywords
# are appended to the end of the CSV and older ones at the top
# get expanded first.
SEED_COUNT=0
SEEDS=()

while IFS=',' read -r vertical keyword url_pattern; do
  # Trim whitespace
  keyword=$(echo "$keyword" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Skip empty
  if [ -z "$keyword" ]; then
    continue
  fi

  SEEDS+=("$keyword")
  SEED_COUNT=$((SEED_COUNT + 1))

  # Stop loading once we hit the seed limit
  if [ "$SEED_COUNT" -ge "$MAX_SEEDS_PER_RUN" ]; then
    break
  fi
done < <(tail -n +2 "$KEYWORDS")

echo "Loaded $SEED_COUNT seed keywords (limit: $MAX_SEEDS_PER_RUN)"

# -----------------------------------------------
# Main: Query autocomplete for each seed
# -----------------------------------------------
for seed in "${SEEDS[@]}"; do

  # Stop if we've hit the safety cap
  if [ "$DISCOVERED" -ge "$MAX_AUTOCOMPLETE_EXPANSIONS" ]; then
    echo "Safety cap reached ($MAX_AUTOCOMPLETE_EXPANSIONS discoveries). Stopping expansion."
    break
  fi

  echo "Expanding: $seed"

  # Query Google Autocomplete
  suggestions=$(query_autocomplete "$seed")

  # Process each suggestion
  while IFS= read -r suggestion; do
    # Skip empty lines
    if [ -z "$suggestion" ]; then
      continue
    fi

    # Lowercase for consistent processing
    suggestion=$(echo "$suggestion" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip if it's identical to the seed (not a new variant)
    if [ "$suggestion" = "$(echo "$seed" | tr '[:upper:]' '[:lower:]')" ]; then
      continue
    fi

    # Check if suggestion matches an insurance vertical
    vertical=$(classify_vertical "$suggestion")
    if [ -z "$vertical" ]; then
      continue
    fi

    # Validate the suggestion as a comparison keyword
    if ! is_valid_suggestion "$suggestion"; then
      echo "  Skipping informational keyword: $suggestion"
      continue
    fi

    # Check for duplicates in the CSV
    if keyword_exists "$suggestion"; then
      echo "  Skipping duplicate keyword: $suggestion"
      continue
    fi

    # Build the URL pattern from vertical + keyword
    url_pattern=$(build_url_pattern "$vertical" "$suggestion")
    if [ -z "$url_pattern" ]; then
      continue
    fi

    # Append new keyword to CSV
    echo "$vertical,$suggestion,$url_pattern" >> "$KEYWORDS"
    DISCOVERED=$((DISCOVERED + 1))
    echo "  Discovered: $suggestion → $url_pattern"

    # Stop if we've hit the safety cap
    if [ "$DISCOVERED" -ge "$MAX_AUTOCOMPLETE_EXPANSIONS" ]; then
      echo "Safety cap reached ($MAX_AUTOCOMPLETE_EXPANSIONS discoveries). Stopping expansion."
      break 2
    fi

  done <<< "$suggestions"

  # Rate limit: avoid hammering Google Autocomplete
  sleep 0.5

done

echo "---------------------------------------"
echo "Autocomplete expansion complete"
echo "New keywords discovered: $DISCOVERED"
echo "======================================="
