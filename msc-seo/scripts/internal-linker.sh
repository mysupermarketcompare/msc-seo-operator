#!/bin/bash

# ===============================================
# Internal Linking Engine
# ===============================================
# Scans all SEO page JSON files, groups them by
# vertical (e.g. car-insurance, pet-insurance),
# then generates internal links per page for SEO
# topical authority.
#
# Features:
#   - Deterministic link selection (alphabetical)
#   - Same-vertical related page links (3–4)
#   - Cross-vertical page-to-page links (1–2)
#   - Cross-vertical fallback links
#   - Hub page fallback links
#   - Zero orphan page guarantee
#   - Broken link validation against page registry
#   - CTA endpoint protection (/now)
#   - Strict URL validation
#   - Anchor text normalization
#
# Uses python3 for safe JSON read/write.
# Runs after sitemap generation and before git push.
# ===============================================

SITE="$HOME/MSCINSURANCE-1"
PAGES="$SITE/src/data/pages"
WORKSPACE="$HOME/.openclaw/workspace/msc-seo"

echo "---------------------------------------"
echo "Running internal linking engine..."

python3 - "$PAGES" "$WORKSPACE" << 'PYTHON_SCRIPT'
import json
import os
import re
import sys

PAGES_DIR = sys.argv[1]
WORKSPACE = sys.argv[2]

# -----------------------------------------------
# Configuration
# -----------------------------------------------
MIN_LINKS = 3
MAX_LINKS = 5

# -----------------------------------------------
# Cross-vertical relationships for fallback linking.
# When a vertical has too few pages, link to these
# related verticals' hub pages.
# -----------------------------------------------
RELATED_VERTICALS = {
    "car-insurance": ["breakdown-cover", "van-insurance"],
    "home-insurance": ["pet-insurance", "travel-insurance"],
    "travel-insurance": ["home-insurance"],
    "van-insurance": ["car-insurance"],
    "pet-insurance": ["home-insurance"],
    "motorbike-insurance": ["breakdown-cover"],
    "bicycle-insurance": ["home-insurance"],
    "breakdown-cover": ["car-insurance"],
    "breakdown-insurance": ["car-insurance"],
}

# -----------------------------------------------
# Helper: is_valid_url
# -----------------------------------------------
def is_valid_url(url):
    if not url or not isinstance(url, str):
        return False
    if not url.startswith("/"):
        return False
    if " " in url or "," in url:
        return False
    if not re.match(r'^/[a-z0-9/-]+$', url):
        return False
    parts = url.strip("/").split("/")
    if len(parts) < 2:
        return False
    return True

# -----------------------------------------------
# Helper: is_cta_url
# -----------------------------------------------
def is_cta_url(url):
    return url.rstrip("/").endswith("/now")

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
# Helper: vertical_display_name
# -----------------------------------------------
def vertical_display_name(slug):
    names = {
        "car-insurance": "Car Insurance",
        "home-insurance": "Home Insurance",
        "van-insurance": "Van Insurance",
        "motorbike-insurance": "Motorbike Insurance",
        "pet-insurance": "Pet Insurance",
        "travel-insurance": "Travel Insurance",
        "bicycle-insurance": "Bicycle Insurance",
        "breakdown-cover": "Breakdown Cover",
        "breakdown-insurance": "Breakdown Cover",
    }
    return names.get(slug, slug.replace("-", " ").title())

# -----------------------------------------------
# Step 1: Load all page JSON files.
# -----------------------------------------------
print(f"Scanning pages in {PAGES_DIR}")

pages = []
skipped_urls = 0
for filename in sorted(os.listdir(PAGES_DIR)):
    if not filename.endswith(".json"):
        continue
    filepath = os.path.join(PAGES_DIR, filename)
    try:
        with open(filepath, "r") as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"  Skipping invalid JSON: {filename} ({e})")
        continue

    url = data.get("url", "")
    keyword = data.get("keyword", "")

    if not url or not keyword:
        continue

    if not is_valid_url(url):
        skipped_urls += 1
        print(f"  Skipping invalid URL: {url} ({filename})")
        continue

    if is_cta_url(url):
        continue

    pages.append({
        "filepath": filepath,
        "filename": filename,
        "keyword": keyword,
        "url": url,
        "data": data,
    })

if skipped_urls > 0:
    print(f"Skipped {skipped_urls} pages with invalid URLs")

# Detect and remove duplicate URLs (keep the shorter filename)
seen_page_urls = {}
duplicates_removed = 0
for page in list(pages):
    url = page["url"]
    if url in seen_page_urls:
        existing = seen_page_urls[url]
        # Keep whichever has the shorter filename (canonical slug)
        if len(page["filename"]) < len(existing["filename"]):
            # New one is shorter, remove old
            pages.remove(existing)
            seen_page_urls[url] = page
            victim = existing
        else:
            # Existing is shorter or equal, remove new
            pages.remove(page)
            victim = page
        print(f"  Duplicate URL: {url}")
        print(f"    Kept:    {seen_page_urls[url]['filename']}")
        print(f"    Removed: {victim['filename']}")
        os.remove(victim["filepath"])
        duplicates_removed += 1
    else:
        seen_page_urls[url] = page

if duplicates_removed > 0:
    print(f"Removed {duplicates_removed} duplicate page files")

# Clean stale internalLinks from pages with invalid URLs
cleaned = 0
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
    if not is_valid_url(url) and "internalLinks" in data:
        del data["internalLinks"]
        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        cleaned += 1
if cleaned > 0:
    print(f"Cleaned stale internalLinks from {cleaned} invalid pages")

print(f"Found {len(pages)} pages")

# -----------------------------------------------
# Step 2: Build page registry and group by vertical.
# -----------------------------------------------
print("Building page registry and grouping by vertical...")

valid_urls = {page["url"] for page in pages}

verticals = {}
for page in pages:
    parts = page["url"].strip("/").split("/")
    if len(parts) < 2:
        continue
    vertical = parts[0]
    if vertical not in verticals:
        verticals[vertical] = []
    verticals[vertical].append(page)

# Sort each vertical's pages alphabetically by URL for determinism
for v in verticals:
    verticals[v].sort(key=lambda p: p["url"])

for v, v_pages in sorted(verticals.items()):
    print(f"  {v}: {len(v_pages)} pages")

# -----------------------------------------------
# Step 3: Audit existing links — find broken ones
# -----------------------------------------------
print("\nAuditing existing links...")
broken_links_found = 0
broken_links_repaired = 0

for page in pages:
    existing = page["data"].get("internalLinks", [])
    for link in existing:
        target = link.get("url", "")
        # Hub links (single segment like /car-insurance/) are always valid
        parts = target.strip("/").split("/")
        if len(parts) < 2:
            continue
        if target not in valid_urls:
            broken_links_found += 1

if broken_links_found > 0:
    print(f"  Found {broken_links_found} broken links — will be repaired")
else:
    print("  No broken links found")

# -----------------------------------------------
# Step 4: Generate internal links for each page.
#
# DETERMINISTIC strategy (no randomness):
#   1. Select same-vertical pages (capped to leave room
#      for cross-vertical links), using round-robin
#      offset for even distribution.
#   2. Add cluster parent/member links if present.
#   3. Add 1-2 cross-vertical page-to-page links
#      (actual pages, not hubs) from related verticals.
#   4. Cap at MAX_LINKS.
#   5. If < MIN_LINKS, add own vertical hub link.
#   6. If still < MIN_LINKS, add cross-vertical hubs.
#   7. Never include CTA /now endpoints.
#   8. Never include self-links.
#   9. Never include broken links (target not in registry).
# -----------------------------------------------
print("\nGenerating links for each page...")

updated_count = 0
total_links = 0

for page in pages:
    parts = page["url"].strip("/").split("/")
    if len(parts) < 2:
        continue
    vertical = parts[0]

    # Get all other pages in this vertical (exclude self, exclude /now)
    # Already sorted alphabetically from Step 2
    related = [
        p for p in verticals.get(vertical, [])
        if p["url"] != page["url"] and not is_cta_url(p["url"])
    ]

    # Deterministic offset: use this page's index within its vertical
    # to rotate which peers it links to, spreading inbound links evenly
    vertical_pages = verticals.get(vertical, [])
    page_index = next(
        (i for i, p in enumerate(vertical_pages) if p["url"] == page["url"]),
        0,
    )

    # Reserve 1-2 slots for cross-vertical page-to-page links
    cross_targets = RELATED_VERTICALS.get(vertical, [])
    cross_slots = min(2, len(cross_targets))
    phase1_cap = max(MIN_LINKS, MAX_LINKS - cross_slots)

    seen_urls = set()
    internal_links = []

    # --- Phase 1: Same-vertical page links (deterministic round-robin) ---
    if related:
        # Rotate the list by page_index so each page links to different peers
        rotated = related[page_index % len(related):] + related[:page_index % len(related)]
        for s in rotated:
            if len(internal_links) >= phase1_cap:
                break
            if s["url"] in seen_urls:
                continue
            if s["url"] not in valid_urls:
                broken_links_repaired += 1
                continue
            seen_urls.add(s["url"])
            internal_links.append({
                "text": make_link_text(s["keyword"]),
                "url": s["url"],
            })

    # --- Phase 1.5: Cluster-aware links ---
    page_data = page["data"]

    if "clusterParent" in page_data and len(internal_links) < MAX_LINKS:
        cp = page_data["clusterParent"]
        cp_url = cp.get("url", "")
        if (cp_url and cp_url not in seen_urls
                and is_valid_url(cp_url) and cp_url in valid_urls):
            seen_urls.add(cp_url)
            internal_links.insert(0, {
                "text": cp.get("text", make_link_text(cp_url.split("/")[-1])),
                "url": cp_url,
            })

    if "clusterPages" in page_data:
        cluster_members = page_data["clusterPages"]
        # Sort deterministically by URL
        unseen_members = sorted(
            [
                m for m in cluster_members
                if m["url"] not in seen_urls
                and is_valid_url(m["url"])
                and m["url"] in valid_urls
            ],
            key=lambda m: m["url"],
        )
        for cm in unseen_members:
            if len(internal_links) >= MAX_LINKS:
                break
            seen_urls.add(cm["url"])
            internal_links.append({
                "text": cm["text"],
                "url": cm["url"],
            })

    # --- Phase 2: Cross-vertical page-to-page links ---
    for cv_vertical in cross_targets:
        if len(internal_links) >= MAX_LINKS:
            break
        cv_pages = verticals.get(cv_vertical, [])
        if not cv_pages:
            continue
        # Deterministic: rotate by page_index for variety across pages
        cv_idx = page_index % len(cv_pages)
        cv_rotated = cv_pages[cv_idx:] + cv_pages[:cv_idx]
        for cv_page in cv_rotated:
            if cv_page["url"] not in seen_urls and not is_cta_url(cv_page["url"]):
                seen_urls.add(cv_page["url"])
                internal_links.append({
                    "text": make_link_text(cv_page["keyword"]),
                    "url": cv_page["url"],
                })
                break

    # --- Cap at MAX_LINKS ---
    internal_links = internal_links[:MAX_LINKS]

    # --- Phase 3: Own vertical hub link ---
    if len(internal_links) < MIN_LINKS:
        hub_url = f"/{vertical}"
        if hub_url not in seen_urls:
            seen_urls.add(hub_url)
            internal_links.append({
                "text": f"Compare {vertical_display_name(vertical)} Quotes",
                "url": hub_url,
            })

    # --- Phase 4: Cross-vertical hub links ---
    if len(internal_links) < MIN_LINKS:
        cross_verticals = RELATED_VERTICALS.get(vertical, [])
        for cv in sorted(cross_verticals):
            if len(internal_links) >= MIN_LINKS:
                break
            cv_hub_url = f"/{cv}"
            if cv_hub_url not in seen_urls:
                seen_urls.add(cv_hub_url)
                internal_links.append({
                    "text": f"Compare {vertical_display_name(cv)} Quotes",
                    "url": cv_hub_url,
                })

    # --- Phase 5: Generic fallback if still under minimum ---
    if len(internal_links) < MIN_LINKS:
        fallback_verticals = ["car-insurance", "home-insurance", "travel-insurance", "pet-insurance"]
        for fv in fallback_verticals:
            if len(internal_links) >= MIN_LINKS:
                break
            fv_hub_url = f"/{fv}"
            if fv_hub_url not in seen_urls and fv != vertical:
                seen_urls.add(fv_hub_url)
                internal_links.append({
                    "text": f"Compare {vertical_display_name(fv)} Quotes",
                    "url": fv_hub_url,
                })

    # Update the page data
    page["data"]["internalLinks"] = internal_links
    total_links += len(internal_links)

    # Write updated JSON back to file
    try:
        with open(page["filepath"], "w") as f:
            json.dump(page["data"], f, indent=2)
            f.write("\n")
        updated_count += 1
    except IOError as e:
        print(f"  Error writing {page['filename']}: {e}")

# -----------------------------------------------
# Step 5: Orphan page analysis and repair.
# -----------------------------------------------
print("\nAnalysing link graph...")

inbound_counts = {page["url"]: 0 for page in pages}

for page in pages:
    for link in page["data"].get("internalLinks", []):
        target = link.get("url", "")
        if target in inbound_counts:
            inbound_counts[target] += 1

orphan_count = sum(1 for url, count in inbound_counts.items() if count == 0)

if orphan_count > 0:
    print(f"Fixing {orphan_count} orphan pages...")
    orphan_pages = sorted(
        [p for p in pages if inbound_counts.get(p["url"], 0) == 0],
        key=lambda p: p["url"],
    )

    for orphan in orphan_pages:
        orphan_parts = orphan["url"].strip("/").split("/")
        orphan_vertical = orphan_parts[0] if len(orphan_parts) >= 2 else ""

        # Try same-vertical donors first (deterministic: alphabetical)
        donor_verticals = [orphan_vertical]
        # Then related verticals
        related_verts = RELATED_VERTICALS.get(orphan_vertical, [])
        for v, rels in sorted(RELATED_VERTICALS.items()):
            if orphan_vertical in rels and v not in donor_verticals:
                donor_verticals.append(v)
        for rv in related_verts:
            if rv not in donor_verticals:
                donor_verticals.append(rv)
        # Fallback
        for fv in ["car-insurance", "home-insurance"]:
            if fv not in donor_verticals:
                donor_verticals.append(fv)

        injected = False
        for dv in donor_verticals:
            if injected:
                break
            for donor in verticals.get(dv, []):
                if donor["url"] == orphan["url"]:
                    continue
                existing_links = donor["data"].get("internalLinks", [])
                existing_urls = {l["url"] for l in existing_links}
                # Only inject if donor won't exceed MAX_LINKS
                if orphan["url"] not in existing_urls and len(existing_links) < MAX_LINKS:
                    donor["data"]["internalLinks"].append({
                        "text": make_link_text(orphan["keyword"]),
                        "url": orphan["url"],
                    })
                    try:
                        with open(donor["filepath"], "w") as f:
                            json.dump(donor["data"], f, indent=2)
                            f.write("\n")
                        inbound_counts[orphan["url"]] = inbound_counts.get(orphan["url"], 0) + 1
                        total_links += 1
                        injected = True
                        print(f"  Injected link to {orphan['url']} from {donor['url']}")
                    except IOError as e:
                        print(f"  Error injecting link: {e}")
                    break

    # If still orphaned (all potential donors at MAX_LINKS), allow one donor to go to MAX_LINKS+1
    for orphan in orphan_pages:
        if inbound_counts.get(orphan["url"], 0) > 0:
            continue
        orphan_parts = orphan["url"].strip("/").split("/")
        orphan_vertical = orphan_parts[0] if len(orphan_parts) >= 2 else ""

        # Build ordered list of verticals to try as donors
        overflow_verticals = [orphan_vertical]
        for rv in RELATED_VERTICALS.get(orphan_vertical, []):
            if rv not in overflow_verticals:
                overflow_verticals.append(rv)
        for v, rels in sorted(RELATED_VERTICALS.items()):
            if orphan_vertical in rels and v not in overflow_verticals:
                overflow_verticals.append(v)
        for fv in ["car-insurance", "home-insurance", "pet-insurance"]:
            if fv not in overflow_verticals:
                overflow_verticals.append(fv)

        injected_overflow = False
        for ov in overflow_verticals:
            if injected_overflow:
                break
            for donor in verticals.get(ov, []):
                if donor["url"] == orphan["url"]:
                    continue
                existing_links = donor["data"].get("internalLinks", [])
                existing_urls = {l["url"] for l in existing_links}
                # Allow at most MAX_LINKS + 1 for orphan rescue
                if orphan["url"] not in existing_urls and len(existing_links) <= MAX_LINKS:
                    donor["data"]["internalLinks"].append({
                        "text": make_link_text(orphan["keyword"]),
                        "url": orphan["url"],
                    })
                    try:
                        with open(donor["filepath"], "w") as f:
                            json.dump(donor["data"], f, indent=2)
                            f.write("\n")
                        inbound_counts[orphan["url"]] = 1
                        total_links += 1
                        injected_overflow = True
                        print(f"  Injected link to {orphan['url']} from {donor['url']} (overflow)")
                    except IOError:
                        pass
                    break

    orphan_count = sum(1 for url, count in inbound_counts.items() if count == 0)

linked_count = sum(1 for url, count in inbound_counts.items() if count > 0)

# -----------------------------------------------
# Step 5.5: Graph connectivity repair
# Ensures all pages form a single connected component.
# If multiple components exist, adds bridge edges between
# them using the alphabetically first eligible pair.
# -----------------------------------------------
print("\nChecking graph connectivity...")

def find_components(pages_list):
    """BFS on undirected edges to find connected components."""
    adj_fwd = {p["url"]: set() for p in pages_list}
    adj_rev = {p["url"]: set() for p in pages_list}
    for p in pages_list:
        for link in p["data"].get("internalLinks", []):
            target = link.get("url", "")
            if target in adj_fwd:
                adj_fwd[p["url"]].add(target)
                adj_rev[target].add(p["url"])

    visited = set()
    components = []
    for start in sorted(adj_fwd):
        if start in visited:
            continue
        comp = []
        queue = [start]
        while queue:
            node = queue.pop(0)
            if node in visited:
                continue
            visited.add(node)
            comp.append(node)
            for t in adj_fwd.get(node, set()):
                if t not in visited:
                    queue.append(t)
            for t in adj_rev.get(node, set()):
                if t not in visited:
                    queue.append(t)
        components.append(sorted(comp))
    return components

components = find_components(pages)
bridges_added = 0

if len(components) > 1:
    print(f"  Found {len(components)} disconnected components — adding bridges...")
    url_to_page = {p["url"]: p for p in pages}

    # Connect each component to the first (largest) component
    main_comp = set(components[0])
    for comp_idx in range(1, len(components)):
        comp_set = set(components[comp_idx])

        # Find a donor in main_comp with room for a link
        # and a target in this component (alphabetically first pair)
        bridged = False
        for donor_url in sorted(main_comp):
            if bridged:
                break
            donor = url_to_page.get(donor_url)
            if not donor:
                continue
            existing = donor["data"].get("internalLinks", [])
            existing_urls = {l["url"] for l in existing}
            if len(existing) >= MAX_LINKS + 1:
                continue
            for target_url in sorted(comp_set):
                if target_url in existing_urls:
                    continue
                target = url_to_page.get(target_url)
                if not target:
                    continue
                donor["data"]["internalLinks"].append({
                    "text": make_link_text(target["keyword"]),
                    "url": target_url,
                })
                try:
                    with open(donor["filepath"], "w") as f:
                        json.dump(donor["data"], f, indent=2)
                        f.write("\n")
                    total_links += 1
                    bridges_added += 1
                    bridged = True
                    print(f"  Bridge: {donor_url} -> {target_url}")
                except IOError:
                    pass
                break

        # Also add reverse bridge for stronger connectivity
        if bridged:
            rev_bridged = False
            for donor_url in sorted(comp_set):
                if rev_bridged:
                    break
                donor = url_to_page.get(donor_url)
                if not donor:
                    continue
                existing = donor["data"].get("internalLinks", [])
                existing_urls = {l["url"] for l in existing}
                if len(existing) >= MAX_LINKS + 1:
                    continue
                for target_url in sorted(main_comp):
                    if target_url in existing_urls:
                        continue
                    target = url_to_page.get(target_url)
                    if not target:
                        continue
                    donor["data"]["internalLinks"].append({
                        "text": make_link_text(target["keyword"]),
                        "url": target_url,
                    })
                    try:
                        with open(donor["filepath"], "w") as f:
                            json.dump(donor["data"], f, indent=2)
                            f.write("\n")
                        total_links += 1
                        bridges_added += 1
                        rev_bridged = True
                        print(f"  Bridge: {donor_url} -> {target_url}")
                    except IOError:
                        pass
                    break

        # Merge into main component
        main_comp.update(comp_set)

    # Verify
    components = find_components(pages)
    print(f"  Components after repair: {len(components)}")
else:
    print("  Graph is fully connected (1 component)")

# -----------------------------------------------
# Step 6: Final validation
# -----------------------------------------------
print("\nRunning final validation...")

# Recount all metrics after all writes
outbound_counts = {}
all_broken = 0
all_self_links = 0
all_duplicates = 0

for page in pages:
    links = page["data"].get("internalLinks", [])
    outbound_counts[page["url"]] = len(links)
    seen = set()
    for link in links:
        target = link.get("url", "")
        # Check broken (only multi-segment URLs, not hub links)
        parts = target.strip("/").split("/")
        if len(parts) >= 2 and target not in valid_urls:
            all_broken += 1
        # Check self-link
        if target == page["url"]:
            all_self_links += 1
        # Check duplicate
        if target in seen:
            all_duplicates += 1
        seen.add(target)

pages_with_3plus = sum(1 for c in outbound_counts.values() if c >= 3)
pages_over_5 = sum(1 for c in outbound_counts.values() if c > MAX_LINKS)
min_out = min(outbound_counts.values()) if outbound_counts else 0
max_out = max(outbound_counts.values()) if outbound_counts else 0

# -----------------------------------------------
# Step 7: Write validation report
# -----------------------------------------------
report_path = os.path.join(WORKSPACE, "reports", "internal-link-report.txt")
os.makedirs(os.path.dirname(report_path), exist_ok=True)

from datetime import datetime

report_lines = [
    "Internal Linking Validation Report",
    f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
    "=" * 45,
    "",
    f"Total pages scanned:        {len(pages)}",
    f"Broken links found:         {broken_links_found}",
    f"Broken links repaired:      {broken_links_repaired}",
    f"Pages with 3+ outbound:     {pages_with_3plus}/{len(pages)}",
    f"Pages with >5 outbound:     {pages_over_5}",
    f"Outbound link range:        {min_out}–{max_out}",
    f"Self-links:                 {all_self_links}",
    f"Duplicate links:            {all_duplicates}",
    f"Orphan pages (0 inbound):   {orphan_count}",
    f"Total links generated:      {total_links}",
    "",
]

# Flag any remaining issues
issues = []
if all_broken > 0:
    issues.append(f"FAIL: {all_broken} broken links remain")
if all_self_links > 0:
    issues.append(f"FAIL: {all_self_links} self-links found")
if all_duplicates > 0:
    issues.append(f"FAIL: {all_duplicates} duplicate links found")
if orphan_count > 0:
    issues.append(f"FAIL: {orphan_count} orphan pages remain")
if pages_over_5 > 0:
    issues.append(f"WARN: {pages_over_5} pages exceed {MAX_LINKS} outbound links")

if issues:
    report_lines.append("Issues:")
    for issue in issues:
        report_lines.append(f"  {issue}")
else:
    report_lines.append("All checks passed.")

report_text = "\n".join(report_lines) + "\n"

with open(report_path, "w") as f:
    f.write(report_text)

# -----------------------------------------------
# Summary
# -----------------------------------------------
print(f"\n{'='*45}")
print(f"Pages processed:        {updated_count}")
print(f"Total links generated:  {total_links}")
print(f"Outbound link range:    {min_out}–{max_out}")
print(f"Pages with 3+ outbound: {pages_with_3plus}/{len(pages)}")
print(f"Broken links found:     {broken_links_found}")
print(f"Broken links repaired:  {broken_links_repaired}")
print(f"Self-links:             {all_self_links}")
print(f"Duplicate links:        {all_duplicates}")
print(f"Orphan pages:           {orphan_count}")
print(f"{'='*45}")

if orphan_count > 0:
    print("\nOrphan pages (zero inbound links):")
    for url, count in sorted(inbound_counts.items()):
        if count == 0:
            print(f"  {url}")

print(f"\nReport written to: {report_path}")
print("Internal linking complete.")
PYTHON_SCRIPT

echo "---------------------------------------"
