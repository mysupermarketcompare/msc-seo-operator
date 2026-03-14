#!/bin/bash

# ===============================================
# Topical Hub Page Generator
# ===============================================
# Scans all generated SEO page JSON files, groups
# them by vertical (first URL path segment), and
# generates a hub JSON file for each vertical.
#
# Hub pages act as topical authority anchors,
# linking to every page within a vertical to
# strengthen crawl depth and indexing speed.
#
# Uses python3 for safe JSON processing.
# ===============================================

SITE="$HOME/MSCINSURANCE-1"
PAGES="$SITE/src/data/pages"
HUBS="$SITE/src/data/hubs"

echo "---------------------------------------"
echo "Running hub page generator..."

# -----------------------------------------------
# Delegate to python3 for reliable JSON processing.
# The script:
#   1. Scans all page JSON files
#   2. Groups pages by vertical
#   3. Generates a hub JSON for each vertical
#   4. Sorts pages alphabetically
#   5. Deduplicates by URL
#   6. Caps at 200 links per hub
# -----------------------------------------------
python3 << 'PYTHON_SCRIPT'
import json
import os
import sys

PAGES_DIR = os.path.expanduser("~/MSCINSURANCE-1/src/data/pages")
HUBS_DIR = os.path.expanduser("~/MSCINSURANCE-1/src/data/hubs")
TAXONOMY_PATH = os.path.expanduser("~/.openclaw/workspace/msc-seo/data/cluster-taxonomy.json")

MAX_LINKS_PER_HUB = 200

# Ensure hubs directory exists
os.makedirs(HUBS_DIR, exist_ok=True)

# -----------------------------------------------
# Step 1: Scan all page JSON files and extract
# keyword + url from each.
# -----------------------------------------------
print(f"Scanning pages in {PAGES_DIR}")

pages = []
for filename in sorted(os.listdir(PAGES_DIR)):
    if not filename.endswith(".json"):
        continue
    filepath = os.path.join(PAGES_DIR, filename)
    try:
        with open(filepath, "r") as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"  Skipping invalid JSON: {filename}")
        continue

    url = data.get("url", "")
    keyword = data.get("keyword", "")

    if not url or not keyword:
        continue
    if not url.startswith("/"):
        continue
    # Skip URLs with spaces (malformed)
    if " " in url:
        continue

    pages.append({"keyword": keyword, "url": url})

print(f"Found {len(pages)} valid pages")

# -----------------------------------------------
# Step 2: Group pages by vertical.
# Vertical = first path segment of URL.
# e.g. /car-insurance/london → car-insurance
# -----------------------------------------------
print("Grouping pages by vertical...")

verticals = {}
for page in pages:
    parts = page["url"].strip("/").split("/")
    if len(parts) < 2:
        continue
    vertical_slug = parts[0]
    if vertical_slug not in verticals:
        verticals[vertical_slug] = []
    verticals[vertical_slug].append(page)

# -----------------------------------------------
# Vertical display names mapping.
# Converts slug to readable name.
# -----------------------------------------------
VERTICAL_NAMES = {
    "car-insurance": "Car Insurance",
    "home-insurance": "Home Insurance",
    "van-insurance": "Van Insurance",
    "motorbike-insurance": "Motorbike Insurance",
    "pet-insurance": "Pet Insurance",
    "travel-insurance": "Travel Insurance",
    "bicycle-insurance": "Bicycle Insurance",
    "breakdown-insurance": "Breakdown Cover",
    "breakdown-cover": "Breakdown Cover",
}

# -----------------------------------------------
# Load cluster taxonomy to identify cluster parents.
# Cluster parents get sorted to the top of hub lists.
# -----------------------------------------------
cluster_parent_slugs = set()
try:
    with open(TAXONOMY_PATH, "r") as f:
        taxonomy = json.load(f)
    for vertical_slug, clusters in taxonomy.items():
        for parent_slug in clusters:
            cluster_parent_slugs.add(f"/{vertical_slug}/{parent_slug}")
    print(f"Loaded cluster taxonomy: {len(cluster_parent_slugs)} cluster parents")
except (json.JSONDecodeError, IOError, FileNotFoundError):
    print("No cluster taxonomy found — hub pages will use default sort")

# -----------------------------------------------
# Helper: Convert keyword to readable title case.
# "car insurance young drivers" → "Car Insurance Young Drivers"
# -----------------------------------------------
def title_case(text):
    return text.title()

# -----------------------------------------------
# Step 3: Generate hub JSON for each vertical.
# -----------------------------------------------
total_links = 0
hubs_generated = 0

for vertical_slug, vertical_pages in sorted(verticals.items()):
    vertical_name = VERTICAL_NAMES.get(vertical_slug, vertical_slug.replace("-", " ").title())

    # Deduplicate by URL
    seen_urls = set()
    unique_pages = []
    for p in vertical_pages:
        if p["url"] not in seen_urls:
            seen_urls.add(p["url"])
            unique_pages.append(p)

    # Sort: cluster parents first, then alphabetically by keyword
    unique_pages.sort(key=lambda p: (
        0 if p["url"] in cluster_parent_slugs else 1,
        p["keyword"].lower(),
    ))

    # Cap at MAX_LINKS_PER_HUB
    capped_pages = unique_pages[:MAX_LINKS_PER_HUB]

    # Build the page links array
    page_links = []
    for p in capped_pages:
        page_links.append({
            "text": title_case(p["keyword"]),
            "url": p["url"],
        })

    # Build hub JSON structure
    hub_data = {
        "vertical": vertical_name.lower(),
        "url": f"/{vertical_slug}/",
        "title": f"Compare {vertical_name} Quotes | MySupermarketCompare",
        "description": f"Compare {vertical_name.lower()} quotes and explore coverage options using our insurance comparison service.",
        "h1": f"Compare {vertical_name} Quotes",
        "sections": [
            {
                "heading": f"{vertical_name} Comparison",
                "content": f"Explore different {vertical_name.lower()} options and compare quotes through our insurance comparison partners.",
            }
        ],
        "pages": page_links,
    }

    # Write hub JSON file
    hub_filename = f"{vertical_slug}-hub.json"
    hub_filepath = os.path.join(HUBS_DIR, hub_filename)
    try:
        with open(hub_filepath, "w") as f:
            json.dump(hub_data, f, indent=2)
            f.write("\n")
        hubs_generated += 1
        total_links += len(page_links)
        print(f"  {vertical_slug}: {len(page_links)} pages → {hub_filename}")
    except IOError as e:
        print(f"  Error writing {hub_filename}: {e}")

# -----------------------------------------------
# Summary
# -----------------------------------------------
print(f"\nVerticals detected: {len(verticals)}")
print(f"Hub pages generated: {hubs_generated}")
print(f"Total links added: {total_links}")
print("Hub page generation complete.")
PYTHON_SCRIPT

echo "---------------------------------------"
