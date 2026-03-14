#!/bin/bash

# ===============================================
# Cluster Page Generator
# ===============================================
# Reads cluster-taxonomy.json and promotes existing
# pages to cluster parents by adding clusterPages
# and clusterParent metadata to page JSONs.
#
# This creates an intermediate layer between hub
# pages and individual comparison pages:
#
#   Hub → Cluster Parent → Member Pages
#
# Safety: never modifies sections, cta, faq, or
# compliance fields. Only adds/updates:
#   - pageType
#   - clusterPages (on parent pages)
#   - clusterParent (on member pages)
#
# Idempotent — safe to re-run on every pipeline
# execution.
# ===============================================

WORKSPACE="$HOME/.openclaw/workspace/msc-seo"
SITE="$HOME/MSCINSURANCE-1"
PAGES="$SITE/src/data/pages"
TAXONOMY="$WORKSPACE/data/cluster-taxonomy.json"

echo "---------------------------------------"
echo "Running cluster page generator..."

# -----------------------------------------------
# Pre-flight: check taxonomy exists
# -----------------------------------------------
if [ ! -f "$TAXONOMY" ]; then
  echo "Cluster taxonomy not found at $TAXONOMY"
  echo "Skipping cluster generation."
  echo "---------------------------------------"
  exit 0
fi

# -----------------------------------------------
# Run the cluster generator via Python
# -----------------------------------------------
python3 << 'PYTHON_SCRIPT'
import json
import os
import sys

# -----------------------------------------------
# Configuration
# -----------------------------------------------
PAGES_DIR = os.path.expanduser("~/MSCINSURANCE-1/src/data/pages")
TAXONOMY_PATH = os.path.expanduser("~/.openclaw/workspace/msc-seo/data/cluster-taxonomy.json")

# -----------------------------------------------
# Step 1: Load taxonomy
# -----------------------------------------------
print(f"Loading cluster taxonomy from {TAXONOMY_PATH}")

try:
    with open(TAXONOMY_PATH, "r") as f:
        taxonomy = json.load(f)
except (json.JSONDecodeError, IOError) as e:
    print(f"Failed to load taxonomy: {e}")
    sys.exit(1)

# -----------------------------------------------
# Step 2: Load all page JSONs into memory
# -----------------------------------------------
print(f"Loading page JSONs from {PAGES_DIR}")

page_cache = {}  # filename -> data dict
for filename in sorted(os.listdir(PAGES_DIR)):
    if not filename.endswith(".json"):
        continue
    filepath = os.path.join(PAGES_DIR, filename)
    try:
        with open(filepath, "r") as f:
            data = json.load(f)
        page_cache[filename] = data
    except (json.JSONDecodeError, IOError):
        continue

print(f"Loaded {len(page_cache)} page JSONs")

# -----------------------------------------------
# Helper: convert slug to title case
# -----------------------------------------------
def title_case(slug):
    return slug.replace("-", " ").title()

# -----------------------------------------------
# Step 3: Process taxonomy — inject cluster
# metadata into page JSONs
# -----------------------------------------------
clusters_created = 0
members_tagged = 0
warnings = []

# Track which pages are members (for detecting
# pages in multiple clusters — first cluster wins
# as primary parent)
member_to_primary_parent = {}

for vertical, clusters in taxonomy.items():
    print(f"\nVertical: {vertical}")

    for parent_slug, cluster_def in clusters.items():
        label = cluster_def.get("label", title_case(parent_slug))
        member_slugs = cluster_def.get("members", [])

        # Validate parent page exists
        parent_filename = f"{vertical}-{parent_slug}.json"
        if parent_filename not in page_cache:
            warnings.append(f"Cluster parent not found: {parent_filename}")
            continue

        parent_data = page_cache[parent_filename]
        parent_url = parent_data.get("url", f"/{vertical}/{parent_slug}")

        # Build clusterPages array from valid members
        cluster_pages = []
        valid_member_count = 0

        for member_slug in member_slugs:
            member_filename = f"{vertical}-{member_slug}.json"
            if member_filename not in page_cache:
                warnings.append(f"  Member not found: {member_filename} (cluster: {parent_slug})")
                continue

            member_data = page_cache[member_filename]
            member_keyword = member_data.get("keyword", member_slug)
            member_url = member_data.get("url", f"/{vertical}/{member_slug}")

            cluster_pages.append({
                "text": title_case(member_keyword),
                "url": member_url,
            })

            # Tag the member with its primary cluster parent
            # (first cluster that claims it wins)
            if member_filename not in member_to_primary_parent:
                member_to_primary_parent[member_filename] = {
                    "text": label,
                    "url": parent_url,
                }

            valid_member_count += 1

        if valid_member_count == 0:
            warnings.append(f"  Cluster {parent_slug} has no valid members — skipped")
            continue

        # Inject cluster metadata into parent page
        parent_data["pageType"] = "cluster"
        parent_data["clusterPages"] = cluster_pages

        clusters_created += 1
        print(f"  {parent_slug}: {valid_member_count} members → cluster parent")

# -----------------------------------------------
# Step 4: Inject clusterParent into member pages
# -----------------------------------------------
print(f"\nTagging member pages with clusterParent...")

for member_filename, parent_info in member_to_primary_parent.items():
    if member_filename in page_cache:
        page_cache[member_filename]["clusterParent"] = parent_info
        members_tagged += 1

# -----------------------------------------------
# Step 5: Write all modified JSONs back to disk
# -----------------------------------------------
print(f"\nWriting updated JSONs...")

files_written = 0
for filename, data in page_cache.items():
    # Only write files that have cluster metadata
    if "pageType" not in data and "clusterParent" not in data:
        continue

    filepath = os.path.join(PAGES_DIR, filename)
    try:
        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        files_written += 1
    except IOError as e:
        warnings.append(f"Failed to write {filename}: {e}")

# -----------------------------------------------
# Step 6: Summary
# -----------------------------------------------
total_pages = len(page_cache)
unclustered = total_pages - clusters_created - members_tagged

print(f"\n{'='*45}")
print(f"Cluster Generator Summary")
print(f"{'='*45}")
print(f"Total pages:          {total_pages}")
print(f"Clusters created:     {clusters_created}")
print(f"Members tagged:       {members_tagged}")
print(f"Unclustered pages:    {unclustered}")
print(f"Files written:        {files_written}")

if warnings:
    print(f"\nWarnings ({len(warnings)}):")
    for w in warnings:
        print(f"  {w}")

print(f"{'='*45}")
PYTHON_SCRIPT

echo "Cluster generation complete."
echo "---------------------------------------"
