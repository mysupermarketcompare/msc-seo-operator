#!/bin/bash

# ===============================================
# Formatting Cleaner
# ===============================================
# Scans all page JSON files and replaces em dashes
# (U+2014) with hyphens (-) in content fields.
#
# Targets: title, description, h1, section headings,
# section content, section bullets, FAQ answers.
#
# Runs after page generation, before sitemap/linking.
# ===============================================

SITE="$HOME/MSCINSURANCE-1"
PAGES="$SITE/src/data/pages"

echo "---------------------------------------"
echo "Running formatting cleaner..."

python3 - "$PAGES" << 'PYTHON_SCRIPT'
import json
import os
import sys

PAGES_DIR = sys.argv[1]
EM_DASH = "\u2014"
HYPHEN = "-"

cleaned_count = 0

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

    def clean(val):
        if val and EM_DASH in val:
            return val.replace(EM_DASH, HYPHEN), True
        return val, False

    # Top-level string fields
    for key in ("title", "description", "h1"):
        val, changed = clean(data.get(key))
        if changed:
            data[key] = val
            modified = True

    # sections
    for section in data.get("sections", []):
        for key in ("heading", "content"):
            val, changed = clean(section.get(key))
            if changed:
                section[key] = val
                modified = True
        new_bullets = []
        for bullet in section.get("bullets", []):
            if EM_DASH in bullet:
                new_bullets.append(bullet.replace(EM_DASH, HYPHEN))
                modified = True
            else:
                new_bullets.append(bullet)
        if section.get("bullets") is not None:
            section["bullets"] = new_bullets

    # faq
    for faq in data.get("faq", []):
        for key in ("question", "answer"):
            val, changed = clean(faq.get(key))
            if changed:
                faq[key] = val
                modified = True

    if modified:
        cleaned_count += 1
        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")

if cleaned_count > 0:
    print(f"Formatting cleaner: replaced em dashes in {cleaned_count} pages")
else:
    print("Formatting cleaner: no em dashes found")
PYTHON_SCRIPT

echo "---------------------------------------"
