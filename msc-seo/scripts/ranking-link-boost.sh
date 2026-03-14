#!/bin/bash

# ===============================================
# Ranking Link Boost (Step 7.5)
# ===============================================
# Runs AFTER the internal linker to inject extra
# inbound links to near-ranking pages identified
# by the ranking optimizer.
#
# For each target, finds 1-2 same-vertical donor
# pages and appends a link to their internalLinks.
# Respects MAX_LINKS + 1 cap from the linker.
#
# Runs after internal linker, before hub pages.
# ===============================================

WORKSPACE="$HOME/.openclaw/workspace/msc-seo"
SITE="$HOME/MSCINSURANCE-1"
PAGES="$SITE/src/data/pages"
BOOST_TARGETS="$WORKSPACE/data/ranking-boost-targets.txt"

echo "---------------------------------------"
echo "Running ranking link boost..."

# Graceful skip if no boost targets
if [ ! -f "$BOOST_TARGETS" ] || [ ! -s "$BOOST_TARGETS" ]; then
  echo "No ranking boost targets found (skipping)"
  echo "---------------------------------------"
  exit 0
fi

python3 - "$PAGES" "$BOOST_TARGETS" << 'PYTHON_SCRIPT'
import json
import os
import re
import sys

PAGES_DIR = sys.argv[1]
BOOST_TARGETS_FILE = sys.argv[2]

MAX_LINKS = 5  # matches internal linker config
MAX_DONORS = 2  # links to inject per target

# -----------------------------------------------
# Helper: make_link_text
# -----------------------------------------------
def make_link_text(keyword):
    text = keyword.replace("-", " ")
    text = " ".join(text.split())
    words = text.split()
    result = []
    for word in words:
        if word.isdigit() or re.match(r'^[0-9]+[a-zA-Z]+$', word):
            result.append(word)
        else:
            result.append(word.capitalize())
    return " ".join(result)

# -----------------------------------------------
# Step 1: Read boost targets
# -----------------------------------------------
with open(BOOST_TARGETS_FILE, "r") as f:
    targets = [line.strip() for line in f if line.strip()]

if not targets:
    print("Ranking link boost:")
    print("  No targets to process")
    sys.exit(0)

# -----------------------------------------------
# Step 2: Load all page data, grouped by vertical
# -----------------------------------------------
all_pages = {}  # url -> {filepath, data, keyword}
verticals = {}  # vertical -> [url, ...]

for filename in sorted(os.listdir(PAGES_DIR)):
    if not filename.endswith(".json"):
        continue
    filepath = os.path.join(PAGES_DIR, filename)
    try:
        with open(filepath, "r") as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError):
        continue

    url = data.get("url", "")
    keyword = data.get("keyword", "")
    if not url or not keyword:
        continue

    parts = url.strip("/").split("/")
    if len(parts) < 2:
        continue

    vertical = parts[0]
    all_pages[url] = {
        "filepath": filepath,
        "data": data,
        "keyword": keyword,
        "vertical": vertical,
    }

    if vertical not in verticals:
        verticals[vertical] = []
    verticals[vertical].append(url)

# Sort each vertical for determinism
for v in verticals:
    verticals[v].sort()

# -----------------------------------------------
# Step 3: Inject links for each target
# -----------------------------------------------
targets_processed = 0
links_injected = 0

for target_url in targets:
    target_url = target_url.strip()
    if target_url not in all_pages:
        continue

    target = all_pages[target_url]
    target_vertical = target["vertical"]
    target_keyword = target["keyword"]

    targets_processed += 1
    donors_found = 0

    # Find same-vertical donor pages
    same_vertical_urls = verticals.get(target_vertical, [])

    for donor_url in same_vertical_urls:
        if donors_found >= MAX_DONORS:
            break

        # No self-links
        if donor_url == target_url:
            continue

        donor = all_pages[donor_url]
        donor_data = donor["data"]
        existing_links = donor_data.get("internalLinks", [])
        existing_urls = {l.get("url", "") for l in existing_links}

        # No duplicates
        if target_url in existing_urls:
            continue

        # Respect MAX_LINKS + 1 cap (same as linker orphan rescue)
        if len(existing_links) > MAX_LINKS:
            continue

        # Inject link
        existing_links.append({
            "text": make_link_text(target_keyword),
            "url": target_url,
        })
        donor_data["internalLinks"] = existing_links

        try:
            with open(donor["filepath"], "w") as f:
                json.dump(donor_data, f, indent=2)
                f.write("\n")
            links_injected += 1
            donors_found += 1
        except IOError:
            pass

# -----------------------------------------------
# Summary
# -----------------------------------------------
print(f"Ranking link boost:")
print(f"  Targets processed: {targets_processed}")
print(f"  Links injected:    {links_injected}")
PYTHON_SCRIPT

echo "---------------------------------------"
