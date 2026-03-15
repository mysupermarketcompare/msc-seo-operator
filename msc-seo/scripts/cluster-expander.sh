#!/bin/bash

AGENT_PLAN="../data/agent-plan.json"

AGENT_CLUSTERS=""

if [ -f "$AGENT_PLAN" ]; then
  AGENT_CLUSTERS=$(jq -r '.expand_clusters[]' "$AGENT_PLAN" 2>/dev/null)
fi

# ===============================================
# Cluster Expansion Engine
# ===============================================
# Generates keyword variations by combining each
# insurance vertical with predefined cluster
# datasets (cities, ages, dog breeds, destinations).
#
# This produces structured, high-quality long-tail
# keywords without any external API calls.
#
# Vertical → cluster mapping:
#   car insurance      → cities + ages
#   home insurance     → cities
#   van insurance      → cities
#   motorbike insurance → ages
#   pet insurance      → dog breeds
#   travel insurance   → destinations
# ===============================================

WORKSPACE="$HOME/.openclaw/workspace/msc-seo"
KEYWORDS="$WORKSPACE/data/target-keywords.csv"
CLUSTERS="$WORKSPACE/data/clusters"

# Safety cap: max new keywords added per run
MAX_CLUSTER_EXPANSIONS=100

# Max words allowed in a generated keyword
MAX_WORD_COUNT=6

echo "======================================="
echo "Cluster Expansion Engine"
echo "Time: $(date)"
echo "======================================="

# -----------------------------------------------
# Helper: safe_slug
# Lowercase, spaces→hyphens, strip punctuation,
# collapse double hyphens, trim edges.
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
# Helper: keyword_exists
# Checks if a keyword already exists in the CSV.
# Returns 0 if duplicate, 1 if new.
# -----------------------------------------------
keyword_exists() {
  local kw="$1"
  if grep -qF ",$kw," "$KEYWORDS" 2>/dev/null; then
    return 0
  fi
  return 1
}

# Counters
GENERATED=0
SKIPPED_DUPES=0
SEEDS_PROCESSED=0

# -----------------------------------------------
# expand_vertical
# Takes a vertical name and a cluster file path.
# For each entry in the cluster file, generates
# a keyword in the format: "{vertical} {modifier}"
# and appends it to the CSV if not a duplicate.
#
# Example:
#   vertical="car insurance", modifier="london"
#   → keyword: "car insurance london"
#   → url: /car-insurance/london
# -----------------------------------------------
expand_vertical() {
  local vertical="$1"
  local cluster_file="$2"

  # Skip if cluster file doesn't exist
  if [ ! -f "$cluster_file" ]; then
    echo "  Cluster file not found: $cluster_file"
    return
  fi

  local vertical_slug
  vertical_slug=$(safe_slug "$vertical")

  while IFS= read -r modifier; do
    # Stop if we've hit the safety cap
    if [ "$GENERATED" -ge "$MAX_CLUSTER_EXPANSIONS" ]; then
      return
    fi

    # Skip empty lines
    modifier=$(echo "$modifier" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$modifier" ]; then
      continue
    fi

    # Build the keyword: "{vertical} {modifier}"
    local keyword="${vertical} ${modifier}"

    # Enforce word count limit
    local word_count
    word_count=$(echo "$keyword" | wc -w | tr -d ' ')
    if [ "$word_count" -gt "$MAX_WORD_COUNT" ]; then
      continue
    fi

    # Check for duplicates
    if keyword_exists "$keyword"; then
      SKIPPED_DUPES=$((SKIPPED_DUPES + 1))
      continue
    fi

    # Build URL: /{vertical-slug}/{modifier-slug}
    local modifier_slug
    modifier_slug=$(safe_slug "$modifier")
    local url_pattern="/${vertical_slug}/${modifier_slug}"

    # Append to CSV
    echo "${vertical},${keyword},${url_pattern}" >> "$KEYWORDS"
    GENERATED=$((GENERATED + 1))
    echo "  + $keyword → $url_pattern"

  done < "$cluster_file"
}

# -----------------------------------------------
# Main: Expand each vertical with its cluster datasets.
# Each vertical is paired with the cluster files
# that make sense for that insurance type.
# -----------------------------------------------

if echo "$AGENT_CLUSTERS" | grep -q "car-insurance"; then
  echo "Expanding car insurance (cities + ages)..."
  expand_vertical "car insurance" "$CLUSTERS/cities-uk.txt"
  SEEDS_PROCESSED=$((SEEDS_PROCESSED + 1))
  expand_vertical "car insurance" "$CLUSTERS/ages.txt"
  SEEDS_PROCESSED=$((SEEDS_PROCESSED + 1))
fi

if [ "$GENERATED" -lt "$MAX_CLUSTER_EXPANSIONS" ] && echo "$AGENT_CLUSTERS" | grep -q "home-insurance"; then
  echo "Expanding home insurance (cities)..."
  expand_vertical "home insurance" "$CLUSTERS/cities-uk.txt"
  SEEDS_PROCESSED=$((SEEDS_PROCESSED + 1))
fi

if [ "$GENERATED" -lt "$MAX_CLUSTER_EXPANSIONS" ] && echo "$AGENT_CLUSTERS" | grep -q "van-insurance"; then
  echo "Expanding van insurance (cities)..."
  expand_vertical "van insurance" "$CLUSTERS/cities-uk.txt"
  SEEDS_PROCESSED=$((SEEDS_PROCESSED + 1))
fi

if [ "$GENERATED" -lt "$MAX_CLUSTER_EXPANSIONS" ] && echo "$AGENT_CLUSTERS" | grep -q "motorbike-insurance"; then
  echo "Expanding motorbike insurance (ages)..."
  expand_vertical "motorbike insurance" "$CLUSTERS/ages.txt"
  SEEDS_PROCESSED=$((SEEDS_PROCESSED + 1))
fi

if [ "$GENERATED" -lt "$MAX_CLUSTER_EXPANSIONS" ] && echo "$AGENT_CLUSTERS" | grep -q "pet-insurance"; then
  echo "Expanding pet insurance (dog breeds)..."
  expand_vertical "pet insurance" "$CLUSTERS/dog-breeds.txt"
  SEEDS_PROCESSED=$((SEEDS_PROCESSED + 1))
fi

if [ "$GENERATED" -lt "$MAX_CLUSTER_EXPANSIONS" ] && echo "$AGENT_CLUSTERS" | grep -q "travel-insurance"; then
  echo "Expanding travel insurance (destinations)..."
  expand_vertical "travel insurance" "$CLUSTERS/travel-destinations.txt"
  SEEDS_PROCESSED=$((SEEDS_PROCESSED + 1))
fi

# -----------------------------------------------
# Summary
# -----------------------------------------------
echo "---------------------------------------"
echo "Cluster expansion complete"
echo "Seeds processed:  $SEEDS_PROCESSED"
echo "New keywords:     $GENERATED"
echo "Skipped dupes:    $SKIPPED_DUPES"
echo "======================================="
