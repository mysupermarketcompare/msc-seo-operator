#!/bin/bash

# ===============================================
# Metadata Optimiser
# ===============================================
# Scans all page JSON files and optimises titles
# and meta descriptions for SERP presentation.
#
# Title rules:
#   - Append "| MySupermarketCompare" if brand missing
#   - Skip if brand already present
#
# Description rules:
#   - If < 140 chars, extend with a short phrase
#   - If > 160 chars, truncate at nearest word boundary
#   - Preserve existing keywords
#
# Runs after formatting cleaner, before sitemap.
# ===============================================

SITE="$HOME/MSCINSURANCE-1"
PAGES="$SITE/src/data/pages"

echo "---------------------------------------"
echo "Running metadata optimiser..."

python3 - "$PAGES" << 'PYTHON_SCRIPT'
import json
import os
import sys

PAGES_DIR = sys.argv[1]
BRAND = "MySupermarketCompare"
BRAND_SUFFIX = " | MySupermarketCompare"
DESC_MIN = 140
DESC_MAX = 160
EXTENSION = " Compare quotes and save today."

titles_updated = 0
descs_adjusted = 0

for filename in sorted(os.listdir(PAGES_DIR)):
    if not filename.endswith(".json"):
        continue
    filepath = os.path.join(PAGES_DIR, filename)
    try:
        with open(filepath) as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError):
        continue

    modified = False

    # --- Title: ensure brand is present ---
    title = data.get("title", "")
    if title and BRAND not in title:
        data["title"] = title + BRAND_SUFFIX
        titles_updated += 1
        modified = True

    # --- Description: enforce 140-160 char range ---
    desc = data.get("description", "")
    if not desc:
        continue

    original_len = len(desc)

    if original_len < DESC_MIN:
        # Clean trailing punctuation before extending
        trimmed = desc.rstrip(" ,;")
        candidate = trimmed + "." + EXTENSION if not trimmed.endswith(".") else trimmed + EXTENSION
        # If extension pushes over 160, trim the extension
        if len(candidate) > DESC_MAX:
            candidate = candidate[:DESC_MAX]
            last_space = candidate.rfind(" ")
            if last_space > DESC_MIN:
                candidate = candidate[:last_space] + "."
        data["description"] = candidate
        descs_adjusted += 1
        modified = True

    elif original_len > DESC_MAX:
        truncated = desc[:DESC_MAX]
        last_space = truncated.rfind(" ")
        if last_space > 100:
            data["description"] = truncated[:last_space] + "..."
        else:
            data["description"] = truncated.rstrip() + "..."
        descs_adjusted += 1
        modified = True

    if modified:
        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")

print(f"Metadata optimiser:")
print(f"  Titles updated:       {titles_updated}")
print(f"  Descriptions adjusted: {descs_adjusted}")
PYTHON_SCRIPT

echo "---------------------------------------"
