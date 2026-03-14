#!/bin/bash

WORKSPACE="$HOME/.openclaw/workspace/msc-seo"
SITEMAPS="$WORKSPACE/data/competitor-sitemaps.txt"
KEYWORDS="$WORKSPACE/data/target-keywords.csv"
TMP="$WORKSPACE/data/tmp-sitemap-urls.txt"

echo "Running competitor sitemap crawler..."

> "$TMP"

while read -r sitemap; do
  echo "Fetching $sitemap"
  curl -s "$sitemap" | \
  grep -oE '<loc>[^<]+' | \
  sed 's/<loc>//' >> "$TMP"
done < "$SITEMAPS"

echo "Extracting structured opportunities..."

grep -E '/car-insurance/|/home-insurance/|/van-insurance/|/pet-insurance/|/travel-insurance/|/motorbike-insurance/' "$TMP" | while read -r url
do

path=$(echo "$url" | sed 's|https://[^/]*||')
vertical_slug=$(echo "$path" | cut -d'/' -f2)

if [ "$vertical_slug" = "car-insurance" ]; then
  vertical="car insurance"
elif [ "$vertical_slug" = "home-insurance" ]; then
  vertical="home insurance"
elif [ "$vertical_slug" = "van-insurance" ]; then
  vertical="van insurance"
elif [ "$vertical_slug" = "motorbike-insurance" ]; then
  vertical="motorbike insurance"
elif [ "$vertical_slug" = "pet-insurance" ]; then
  vertical="pet insurance"
elif [ "$vertical_slug" = "travel-insurance" ]; then
  vertical="travel insurance"
else
  continue
fi
slug=$(echo "$path" | cut -d'/' -f3)

# skip empty or bad entries
if [ -z "$slug" ]; then
continue
fi

# skip guides/blog content
if [[ "$slug" == *guide* || "$slug" == *blog* || "$slug" == *news* ]]; then
continue
fi

keyword=$(echo "$slug" | sed 's|-| |g')

pattern="/$vertical/$slug"
if [[ "$slug" == *calculator* || "$slug" == *report* || "$slug" == *planner* ]]; then
continue
fi
if ! grep -q "$pattern" "$KEYWORDS"; then
echo "$vertical,$keyword,$pattern" >> "$KEYWORDS"
echo "Discovered: $vertical → $keyword"
fi

done

echo "Competitor crawl complete."
