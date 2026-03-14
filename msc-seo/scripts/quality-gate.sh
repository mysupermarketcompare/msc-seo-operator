#!/bin/bash
# ============================================================
# quality-gate.sh — MSC SEO page validator
#
# Validates a generated page JSON before it enters the
# production pipeline. Rejects pages that fail content,
# structural, URL, CTA, or vertical contamination checks.
#
# Usage:  scripts/quality-gate.sh <page-file.json>
# Exit:   0 = PASS, 1 = FAIL (page deleted)
# ============================================================

set -euo pipefail

PAGE_FILE="${1:-}"

if [ -z "$PAGE_FILE" ]; then
  echo "FAIL: No page file specified."
  echo "Usage: quality-gate.sh <page-file.json>"
  exit 1
fi

if [ ! -f "$PAGE_FILE" ]; then
  echo "FAIL: File not found — $PAGE_FILE"
  exit 1
fi

# Run all validation in a single Python process
python3 - "$PAGE_FILE" << 'PYEOF'
import json
import sys
import re
import os

filepath = sys.argv[1]
failures = []

# ----------------------------------------------------------
# 1. JSON parse
# ----------------------------------------------------------
try:
    with open(filepath) as f:
        data = json.load(f)
except json.JSONDecodeError as e:
    print(f"FAIL [{os.path.basename(filepath)}]: Invalid JSON — {e}")
    os.remove(filepath)
    sys.exit(1)
except Exception as e:
    print(f"FAIL [{os.path.basename(filepath)}]: Cannot read file — {e}")
    sys.exit(1)

basename = os.path.basename(filepath)

# ----------------------------------------------------------
# 2. Structural validation — required fields
# ----------------------------------------------------------
REQUIRED_FIELDS = [
    "keyword", "url", "title", "description",
    "h1", "sections", "faq", "compliance"
]

for field in REQUIRED_FIELDS:
    val = data.get(field)
    if val is None:
        failures.append(f"missing required field: {field}")
    elif isinstance(val, str) and not val.strip():
        failures.append(f"empty required field: {field}")
    elif isinstance(val, list) and len(val) == 0:
        failures.append(f"empty required field: {field}")

# ----------------------------------------------------------
# 3. Content quality
# ----------------------------------------------------------
words = 0
for s in data.get("sections", []):
    content = s.get("content", "")
    if content:
        words += len(content.split())
    heading = s.get("heading")
    if heading:
        words += len(heading.split())
    for b in s.get("bullets", []):
        words += len(b.split())

for fq in data.get("faq", []):
    answer = fq.get("answer", "")
    if answer:
        words += len(answer.split())
    question = fq.get("question", "")
    if question:
        words += len(question.split())

section_count = len(data.get("sections", []))
faq_count = len(data.get("faq", []))

if words < 700:
    failures.append(f"word count {words} < 700")
if section_count < 6:
    failures.append(f"sections {section_count} < 6")
if faq_count < 5:
    failures.append(f"FAQ entries {faq_count} < 5")

# ----------------------------------------------------------
# 4. URL validation — must match /{vertical}/{slug}
# ----------------------------------------------------------
VALID_VERTICALS = [
    "car-insurance",
    "home-insurance",
    "van-insurance",
    "motorbike-insurance",
    "pet-insurance",
    "travel-insurance",
    "bicycle-insurance",
    "breakdown-cover",
]

url = data.get("url", "")
url_match = re.match(r"^/([a-z0-9-]+)/([a-z0-9-]+)$", url)

if not url_match:
    failures.append(f"URL does not match /{{vertical}}/{{slug}} pattern: {url}")
else:
    vertical_in_url = url_match.group(1)
    if vertical_in_url not in VALID_VERTICALS:
        failures.append(
            f"URL vertical '{vertical_in_url}' not in approved list: {url}"
        )

# ----------------------------------------------------------
# 5. CTA validation — page must contain /{vertical}/now
# ----------------------------------------------------------
if url_match:
    vertical_in_url = url_match.group(1)
    expected_cta = f"/{vertical_in_url}/now"
else:
    # Fall back: try to extract vertical from url's first segment
    parts = url.strip("/").split("/")
    expected_cta = f"/{parts[0]}/now" if parts else None

page_text = json.dumps(data)

if expected_cta and expected_cta not in page_text:
    failures.append(f"missing CTA endpoint: {expected_cta}")

# ----------------------------------------------------------
# 6. Vertical contamination check
# ----------------------------------------------------------
# Build a lowercase version of all text content for matching
all_text_parts = []
for s in data.get("sections", []):
    if s.get("content"):
        all_text_parts.append(s["content"])
    if s.get("heading"):
        all_text_parts.append(s["heading"])
    for b in s.get("bullets", []):
        all_text_parts.append(b)
for fq in data.get("faq", []):
    if fq.get("answer"):
        all_text_parts.append(fq["answer"])
    if fq.get("question"):
        all_text_parts.append(fq["question"])

content_lower = " ".join(all_text_parts).lower()

# Determine the page's vertical from its URL
page_vertical = None
if url_match:
    page_vertical = url_match.group(1)
elif url.startswith("/"):
    parts = url.strip("/").split("/")
    if parts:
        page_vertical = parts[0]

# Contamination rules: { vertical: [forbidden_phrases] }
CONTAMINATION_RULES = {
    "pet-insurance": [
        "vehicle",
        "driver",
        "mileage",
        "no claims",
    ],
    "travel-insurance": [
        "vehicle security",
        "alarms",
        "locks",
    ],
    "breakdown-cover": [
        "no claims bonus",
    ],
    "car-insurance": [
        "vet",
        "breed",
        "pre-existing condition",
    ],
    "van-insurance": [
        "vet",
        "breed",
        "pre-existing condition",
    ],
    "motorbike-insurance": [
        "vet",
        "breed",
        "pre-existing condition",
    ],
}

if page_vertical and page_vertical in CONTAMINATION_RULES:
    for phrase in CONTAMINATION_RULES[page_vertical]:
        if phrase in content_lower:
            failures.append(
                f"vertical contamination: '{phrase}' found in {page_vertical} page"
            )

# ----------------------------------------------------------
# Verdict
# ----------------------------------------------------------
if failures:
    print(f"FAIL [{basename}]:")
    for f in failures:
        print(f"  - {f}")
    # Delete the invalid page
    try:
        os.remove(filepath)
        print(f"  Deleted: {filepath}")
    except OSError:
        pass
    sys.exit(1)
else:
    print(f"PASS [{basename}]: {words} words, {section_count} sections, {faq_count} FAQs")
    sys.exit(0)
PYEOF
