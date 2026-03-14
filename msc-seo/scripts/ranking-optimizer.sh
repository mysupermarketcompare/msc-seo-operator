#!/bin/bash

# ===============================================
# Ranking Optimizer (Step 5.7)
# ===============================================
# Identifies pages close to ranking (impressions > 50,
# position 10-40) from GSC report data, then:
#   1. Rewrites titles to put keyword first
#   2. Adds an additional-information section
#   3. Writes boost targets list for link injection
#
# Runs after metadata optimiser, before sitemap.
# ===============================================

WORKSPACE="$HOME/.openclaw/workspace/msc-seo"
SITE="$HOME/MSCINSURANCE-1"
PAGES="$SITE/src/data/pages"
GSC_REPORT="$WORKSPACE/data/gsc-report.csv"
BOOST_TARGETS="$WORKSPACE/data/ranking-boost-targets.txt"

echo "---------------------------------------"
echo "Running ranking optimizer..."

# Graceful skip if no GSC data
if [ ! -f "$GSC_REPORT" ]; then
  echo "GSC report not found at $GSC_REPORT (skipping)"
  echo "---------------------------------------"
  exit 0
fi

python3 - "$PAGES" "$GSC_REPORT" "$BOOST_TARGETS" << 'PYTHON_SCRIPT'
import csv
import json
import os
import re
import sys

PAGES_DIR = sys.argv[1]
GSC_REPORT = sys.argv[2]
BOOST_TARGETS = sys.argv[3]

BRAND = "MySupermarketCompare"
BRAND_SUFFIX = " | MySupermarketCompare"
DOMAIN = "https://mysupermarketcompare.com"

# Counters
pages_analysed = 0
near_ranking = 0
titles_improved = 0
sections_added = 0

# -----------------------------------------------
# Step 1: Parse GSC report and filter near-ranking
# -----------------------------------------------
candidates = []

with open(GSC_REPORT, "r") as f:
    reader = csv.DictReader(f)
    for row in reader:
        pages_analysed += 1
        try:
            impressions = int(row.get("impressions", 0))
            position = float(row.get("position", 0))
        except (ValueError, TypeError):
            continue

        if impressions > 50 and 10 <= position <= 40:
            candidates.append(row)

near_ranking = len(candidates)

# -----------------------------------------------
# Step 2: Process each candidate
# -----------------------------------------------
boost_urls = []

for row in candidates:
    url = row.get("url", "").strip()
    if not url:
        continue

    # Map GSC URL to page file: strip domain, replace / with -
    path = url.replace(DOMAIN, "")  # e.g. /car-insurance/17-year-olds
    path = path.strip("/")          # e.g. car-insurance/17-year-olds
    filename = path.replace("/", "-") + ".json"  # e.g. car-insurance-17-year-olds.json
    filepath = os.path.join(PAGES_DIR, filename)

    if not os.path.isfile(filepath):
        continue

    try:
        with open(filepath, "r") as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError):
        continue

    modified = False
    keyword = data.get("keyword", "")
    url_path = data.get("url", "")

    if not keyword or not url_path:
        continue

    # Extract vertical from URL
    parts = url_path.strip("/").split("/")
    vertical = parts[0].replace("-", " ").title() if len(parts) >= 2 else ""
    keyword_title = keyword.title()

    # -----------------------------------------------
    # Title improvement: put keyword first
    # Format: "{Keyword} {Vertical} - Compare UK Quotes | MySupermarketCompare"
    # Skip if keyword already at start
    # Omit vertical if keyword already contains it
    # -----------------------------------------------
    title = data.get("title", "")
    if title and not title.lower().startswith(keyword.lower()):
        # Check if keyword already contains the vertical
        keyword_lower = keyword.lower()
        vertical_lower = vertical.lower()
        if vertical_lower and vertical_lower in keyword_lower:
            new_title = f"{keyword_title} - Compare UK Quotes{BRAND_SUFFIX}"
        else:
            new_title = f"{keyword_title} {vertical} - Compare UK Quotes{BRAND_SUFFIX}"

        data["title"] = new_title
        titles_improved += 1
        modified = True

    # -----------------------------------------------
    # Content expansion: insert additional-information
    # section before compare-cta
    # -----------------------------------------------
    sections = data.get("sections", [])

    # Check if section already exists (idempotent)
    has_additional = any(s.get("id") == "additional-information" for s in sections)

    if not has_additional:
        # Find the compare-cta index
        cta_index = None
        for i, s in enumerate(sections):
            if s.get("id") == "compare-cta":
                cta_index = i
                break

        if cta_index is not None:
            additional_section = {
                "id": "additional-information",
                "heading": f"Additional Information About {keyword_title}",
                "content": (
                    f"When comparing {keyword.lower()} options, it is worth taking the time to "
                    f"understand what different policies offer and how they fit your specific needs. "
                    f"Providers may vary in the cover they include as standard, the excess amounts they "
                    f"set, and the optional extras available. Reviewing these details carefully can help "
                    f"you make a more informed decision and avoid paying for features you do not need. "
                    f"MySupermarketCompare makes it easy to compare {keyword.lower()} quotes side by "
                    f"side, so you can see the differences at a glance."
                ),
            }
            sections.insert(cta_index, additional_section)
            data["sections"] = sections
            sections_added += 1
            modified = True

    if modified:
        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")

    # Add to boost targets regardless of whether we modified (it's near-ranking)
    boost_urls.append(url_path)

# -----------------------------------------------
# Step 3: Write boost targets for link injection step
# -----------------------------------------------
os.makedirs(os.path.dirname(BOOST_TARGETS), exist_ok=True)
with open(BOOST_TARGETS, "w") as f:
    for u in boost_urls:
        f.write(u + "\n")

# -----------------------------------------------
# Summary
# -----------------------------------------------
print(f"Ranking optimizer:")
print(f"  Pages analysed:       {pages_analysed}")
print(f"  Near-ranking found:   {near_ranking}")
print(f"  Titles improved:      {titles_improved}")
print(f"  Sections added:       {sections_added}")
PYTHON_SCRIPT

echo "---------------------------------------"
