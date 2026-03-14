#!/bin/bash
# ============================================================
# One-time repair script for existing page JSON files.
#
# Fixes:
#   1. Titles — adds vertical name where missing
#   2. Contaminated cost-factors bullets — replaces generic
#      bullets with vertical-specific ones
#   3. Travel tips contamination — removes "alarms, locks"
#      bullet from travel-insurance tips section
#   4. Meta descriptions — trims to under 160 characters
#
# Safe: only modifies specific fields, preserves all other
# content including custom sections and internal links.
# ============================================================

SITE="$HOME/MSCINSURANCE-1"
PAGES="$SITE/src/data/pages"

echo "======================================="
echo "Repairing existing pages..."
echo "======================================="

python3 - "$PAGES" << 'PYTHON_SCRIPT'
import json
import os
import sys
import glob
import re

PAGES_DIR = sys.argv[1]

# -----------------------------------------------
# Vertical-specific cost-factors bullet replacements
# -----------------------------------------------
VERTICAL_BULLETS = {
    "car-insurance": [
        "Your age and driving experience — younger and newly qualified drivers typically pay more",
        "Your vehicle's insurance group — cars are rated from group 1 (cheapest) to group 50 based on value, performance, and repair costs",
        "Your annual mileage — higher mileage generally means higher premiums",
        "Your claims history and no-claims discount — a clean record can significantly reduce your premium",
        "Your postcode — accident and theft rates in your area affect pricing",
        "Your voluntary excess — choosing a higher excess can lower your premium",
        "Vehicle security — factory-fitted immobilisers and trackers can help reduce costs",
    ],
    "home-insurance": [
        "Your property type — detached houses, flats, and older buildings each carry different risk profiles",
        "The rebuild cost of your home — this is the cost to rebuild from scratch, not the market value",
        "Your location and flood risk — properties in flood-prone or high-crime areas may cost more to insure",
        "Your claims history — previous claims can increase your premium",
        "The total value of your contents — higher-value belongings mean higher premiums",
        "Security measures in place — burglar alarms, window locks, and deadlocks can help reduce costs",
        "Your voluntary excess — a higher excess typically means a lower premium",
    ],
    "pet-insurance": [
        "Your pet's breed — some breeds are more prone to hereditary conditions and cost more to insure",
        "Your pet's age — older pets typically have higher premiums due to increased health risks",
        "Any pre-existing conditions — most policies exclude conditions your pet already has",
        "The level of cover you choose — lifetime cover costs more than accident-only or time-limited policies",
        "The vet fee limit — higher annual limits mean higher premiums but better protection",
        "Your excess amount — a higher excess reduces your premium but means you pay more per claim",
        "Your location — vet costs vary by region, which affects premiums",
    ],
    "travel-insurance": [
        "Your destination — higher-risk regions or countries with expensive healthcare cost more to cover",
        "Your trip duration — longer trips carry more risk and higher premiums",
        "Your age — older travellers may face higher premiums due to increased health risks",
        "Any pre-existing medical conditions — these must be declared and may increase your premium",
        "Planned activities — adventure sports, skiing, or scuba diving may need additional cover",
        "The value of baggage and personal belongings you are taking",
        "The level of cover you choose — basic, standard, or comprehensive",
    ],
    "van-insurance": [
        "Your use type — social, business, or courier use each carry different risk levels and premiums",
        "Your van's payload capacity and size — larger, heavier vans typically cost more to insure",
        "Your annual mileage — higher mileage increases risk and premium cost",
        "Your driving experience and age — younger or less experienced drivers pay more",
        "Where you park your van overnight — secure off-street parking can reduce premiums",
        "Any modifications to your van — non-standard modifications can increase costs",
        "Your claims history — a clean record helps keep premiums down",
    ],
    "motorbike-insurance": [
        "Your bike's engine size (cc) — higher-powered bikes cost more to insure",
        "Your age and riding experience — younger and less experienced riders typically pay higher premiums",
        "Your bike's value and desirability — high-value or commonly stolen models attract higher premiums",
        "Where and how you store your bike — garage storage is cheaper than on-street parking",
        "Any modifications — aftermarket exhausts, performance upgrades, or cosmetic changes can increase costs",
        "Your claims history — a claim-free record helps keep premiums down",
        "Your annual mileage — lower mileage generally means lower premiums",
    ],
    "bicycle-insurance": [
        "Your bike's value — more expensive bikes cost more to insure, especially high-end road bikes and e-bikes",
        "Your bike type — road bikes, e-bikes, and mountain bikes each carry different risk profiles",
        "Theft risk in your postcode — areas with higher bike theft rates attract higher premiums",
        "The value of accessories — lights, GPS units, and other accessories add to the total insured value",
        "How you use your bike — commuting, leisure, and competitive use may affect pricing",
        "Where you store your bike — secure indoor storage is better than outdoor storage",
    ],
    "breakdown-cover": [
        "The cover level you choose — roadside-only is cheapest while full recovery with onward travel costs more",
        "Your vehicle's age — older vehicles may cost more to cover due to higher breakdown risk",
        "Your annual mileage — higher mileage means more time on the road and higher risk",
        "The number of callouts included — some policies limit callouts per year",
        "Whether you choose personal or vehicle-based cover — personal cover protects you in any vehicle",
    ],
    "breakdown-insurance": [
        "The cover level you choose — roadside-only is cheapest while full recovery with onward travel costs more",
        "Your vehicle's age — older vehicles may cost more to cover due to higher breakdown risk",
        "Your annual mileage — higher mileage means more time on the road and higher risk",
        "The number of callouts included — some policies limit callouts per year",
        "Whether you choose personal or vehicle-based cover — personal cover protects you in any vehicle",
    ],
}

# -----------------------------------------------
# Vertical-specific tips bullets (replaces generic ones
# that contained contaminating vocabulary)
# -----------------------------------------------
VERTICAL_TIPS = {
    "travel-insurance": [
        "Choose between single-trip and annual multi-trip — if you travel more than twice a year, an annual policy is usually cheaper",
        "Declare all pre-existing medical conditions upfront — failing to disclose could invalidate your entire policy",
        "Check if you have a valid GHIC or EHIC — this provides access to state healthcare in Europe but is not a substitute for travel insurance",
        "Only add activity cover you actually need — unnecessary extras increase your premium",
        "Compare excess amounts — a lower excess means you pay less per claim but your premium may be higher",
        "Buy your travel insurance as soon as you book — this gives you cancellation cover from day one",
    ],
}

# -----------------------------------------------
# Title builder — matches the template's build_title()
# -----------------------------------------------
VERTICAL_DISPLAY = {
    "car-insurance": "Car Insurance",
    "home-insurance": "Home Insurance",
    "van-insurance": "Van Insurance",
    "motorbike-insurance": "Motorbike Insurance",
    "pet-insurance": "Pet Insurance",
    "travel-insurance": "Travel Insurance",
    "bicycle-insurance": "Bicycle Insurance",
    "breakdown-cover": "Breakdown Cover",
    "breakdown-insurance": "Breakdown Insurance",
}

def build_title(kw_title, vertical_title):
    vt_lower = vertical_title.lower()
    kt_lower = kw_title.lower()
    if vt_lower in kt_lower:
        return f"{kw_title} — Compare UK Quotes | MySupermarketCompare"
    return f"{vertical_title} for {kw_title} — Compare UK Quotes | MySupermarketCompare"

def get_kw_title(keyword):
    """Title case a keyword."""
    words = keyword.split()
    return " ".join(
        w if w.isdigit() or re.match(r'^[0-9]+[a-zA-Z]+$', w) else w.capitalize()
        for w in words
    )

# -----------------------------------------------
# Contamination patterns to detect
# -----------------------------------------------
GENERIC_BULLET_PATTERN = "vehicle type, property size, pet breed, or destination"
TRAVEL_CONTAMINATION = "alarms, locks, and safe storage"

# -----------------------------------------------
# Process each page
# -----------------------------------------------
files = sorted(glob.glob(os.path.join(PAGES_DIR, "*.json")))
print(f"Scanning {len(files)} pages...")

titles_fixed = 0
bullets_fixed = 0
tips_fixed = 0
descriptions_fixed = 0
errors = 0

for filepath in files:
    try:
        with open(filepath) as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError):
        errors += 1
        continue

    modified = False
    url = data.get("url", "")
    keyword = data.get("keyword", "")
    parts = url.strip("/").split("/")
    vertical = parts[0] if parts else ""
    vertical_title = VERTICAL_DISPLAY.get(vertical, vertical.replace("-", " ").title())
    kw_title = get_kw_title(keyword)

    # --- Fix 1: Title ---
    old_title = data.get("title", "")
    new_title = build_title(kw_title, vertical_title)
    if old_title != new_title:
        data["title"] = new_title
        titles_fixed += 1
        modified = True

    # --- Fix 2: Cost-factors bullets ---
    for section in data.get("sections", []):
        if section.get("id") == "cost-factors":
            bullets = section.get("bullets", [])
            has_contamination = any(GENERIC_BULLET_PATTERN in b for b in bullets)
            if has_contamination and vertical in VERTICAL_BULLETS:
                section["bullets"] = VERTICAL_BULLETS[vertical]
                bullets_fixed += 1
                modified = True

    # --- Fix 3: Travel tips contamination ---
    if vertical in VERTICAL_TIPS:
        for section in data.get("sections", []):
            if "tips" in section.get("id", "") or "reduce" in section.get("id", ""):
                bullets = section.get("bullets", [])
                if any(TRAVEL_CONTAMINATION in b for b in bullets):
                    section["bullets"] = VERTICAL_TIPS[vertical]
                    tips_fixed += 1
                    modified = True

    # --- Fix 4: Meta description length ---
    desc = data.get("description", "")
    if len(desc) > 160:
        # Truncate to last complete sentence under 157 chars + "..."
        truncated = desc[:157]
        # Find last period or comma
        last_period = truncated.rfind(".")
        last_comma = truncated.rfind(",")
        cut_point = max(last_period, last_comma)
        if cut_point > 80:
            data["description"] = desc[:cut_point + 1]
        else:
            # Just truncate at word boundary
            truncated = desc[:155]
            last_space = truncated.rfind(" ")
            data["description"] = desc[:last_space] + "..."
        if data["description"] != desc:
            descriptions_fixed += 1
            modified = True

    # --- Write back if modified ---
    if modified:
        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")

print(f"\nRepair complete:")
print(f"  Titles fixed:         {titles_fixed}")
print(f"  Cost-factors fixed:   {bullets_fixed}")
print(f"  Travel tips fixed:    {tips_fixed}")
print(f"  Descriptions trimmed: {descriptions_fixed}")
print(f"  Errors:               {errors}")
PYTHON_SCRIPT

echo "======================================="
