#!/bin/bash

# ===============================================
# Vertical-Specific Page Template Generator
# ===============================================
# Generates SEO page JSON with content tailored to
# each insurance vertical. Eliminates cross-vertical
# contamination (e.g. pet pages mentioning vehicles).
#
# Usage:
#   bash scripts/page-templates.sh <vertical_slug> <keyword> <url_pattern> <kw_title> <vertical_title>
#
# Output: JSON to stdout
#
# Uses python3 for safe JSON serialization.
# ===============================================

if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <vertical_slug> <keyword> <url_pattern> <kw_title> <vertical_title>" >&2
  exit 1
fi

VERTICAL_SLUG="$1"
KEYWORD="$2"
URL_PATTERN="$3"
KW_TITLE="$4"
VERTICAL_TITLE="$5"

python3 - "$VERTICAL_SLUG" "$KEYWORD" "$URL_PATTERN" "$KW_TITLE" "$VERTICAL_TITLE" << 'PYTHON_SCRIPT'
import json
import sys

vertical_slug = sys.argv[1]
keyword = sys.argv[2]
url_pattern = sys.argv[3]
kw_title = sys.argv[4]
vertical_title = sys.argv[5]

# -----------------------------------------------
# Shared compliance block — identical for all verticals
# -----------------------------------------------
COMPLIANCE = {
    "seopa": True,
    "disclaimerRequired": True,
    "notes": "MySupermarketCompare is an introducer to Quotezone. Policies are provided by insurers within the comparison panel. No specific savings claims are made.",
}

# -----------------------------------------------
# Title builder — includes vertical name to prevent
# duplicate titles across verticals (e.g. "Over 50s"
# appearing in both car and home insurance).
# If kw_title already contains the vertical name,
# it is used as-is to avoid redundancy.
# -----------------------------------------------
def build_title(kw_title, vertical_title):
    vt_lower = vertical_title.lower()
    kt_lower = kw_title.lower()
    if vt_lower in kt_lower:
        return f"{kw_title} — Compare UK Quotes | MySupermarketCompare"
    return f"{vertical_title} for {kw_title} — Compare UK Quotes | MySupermarketCompare"

# -----------------------------------------------
# Shared sections used across all verticals
# -----------------------------------------------

def build_how_to_compare_section(keyword, kw_title):
    return {
        "id": "how-to-compare",
        "heading": f"How To Compare {kw_title} Quotes",
        "content": (
            f"Comparing {keyword} quotes through MySupermarketCompare is straightforward. "
            f"Start by entering your details into the comparison form — this typically includes "
            f"information about yourself and what you need to insure. The comparison service, "
            f"powered by Quotezone, then searches across a panel of UK insurance providers and "
            f"returns a list of quotes for you to review. You can compare policies by price, "
            f"cover level, excess amounts, and included features. Once you find a policy that "
            f"suits your needs, you can proceed directly to the provider to complete your "
            f"purchase. There is no obligation to buy, and using the comparison tool is completely free."
        ),
    }

def build_cta_section(keyword, kw_title, vertical_slug):
    return {
        "id": "compare-cta",
        "heading": f"Compare {kw_title} Quotes Today",
        "content": (
            f"Ready to see what is available? Use MySupermarketCompare to compare {keyword} "
            f"quotes from a panel of UK providers. Our free comparison service, powered by "
            f"Quotezone, makes it easy to explore your options and find cover that fits your "
            f"needs and budget."
        ),
        "cta": {
            "text": "Compare Quotes",
            "url": f"/{vertical_slug}/now",
        },
    }

def build_comparison_faq(keyword):
    return {
        "question": f"How does the comparison process work?",
        "answer": (
            f"Simply enter your details into the comparison form on MySupermarketCompare. "
            f"Our service, powered by Quotezone, searches across a panel of UK insurance "
            f"providers and returns a list of quotes. You can then compare prices, cover "
            f"levels, and policy features before deciding whether to proceed with a provider."
        ),
    }


# -----------------------------------------------
# Car Insurance
# -----------------------------------------------
def build_car_insurance_page(keyword, url_pattern, kw_title, vertical_title, vertical_slug):
    return {
        "keyword": keyword,
        "url": url_pattern,
        "title": build_title(kw_title, vertical_title),
        "description": f"Compare {keyword} quotes from a panel of UK car insurance providers. Explore cover levels, prices, and policy features to find the right car insurance for your needs with MySupermarketCompare.",
        "h1": f"Compare {kw_title} Quotes",
        "sections": [
            {
                "id": "introduction",
                "heading": None,
                "content": (
                    f"Comparing {keyword} quotes can help you find the right level of cover "
                    f"at a competitive price. Whether you are a new driver looking for your first policy, "
                    f"an experienced motorist approaching renewal, or switching providers to get a better "
                    f"deal, a comparison service lets you review quotes from multiple UK car insurers in "
                    f"one place. MySupermarketCompare works with Quotezone to search across a wide panel "
                    f"of providers, helping you compare {keyword} options quickly and easily."
                ),
            },
            {
                "id": "how-it-works",
                "heading": f"How {kw_title} Works",
                "content": (
                    f"Car insurance protects you financially if your vehicle is damaged, stolen, or "
                    f"involved in an accident. There are three main levels of cover: third party only "
                    f"(the legal minimum), third party fire and theft, and fully comprehensive. Third "
                    f"party only covers damage you cause to other people and their property. Third party "
                    f"fire and theft adds cover if your car is stolen or damaged by fire. Comprehensive "
                    f"cover includes all of the above plus damage to your own vehicle. Comparing "
                    f"{keyword} quotes lets you see how different providers price each level of cover "
                    f"and what extras are included."
                ),
            },
            {
                "id": "cost-factors",
                "heading": f"What Affects The Cost Of {kw_title}",
                "content": f"Car insurers assess several factors when calculating your {keyword} premium. Understanding these can help you find ways to manage costs.",
                "bullets": [
                    "Your age and driving experience — younger and newly qualified drivers typically pay more",
                    "Your vehicle's insurance group — cars are rated from group 1 (cheapest) to group 50 based on value, performance, and repair costs",
                    "Your annual mileage — higher mileage generally means higher premiums",
                    "Your claims history and no-claims discount — a clean record can significantly reduce your premium",
                    "Your postcode — accident and theft rates in your area affect pricing",
                    "Your voluntary excess — choosing a higher excess can lower your premium",
                    "Vehicle security — factory-fitted immobilisers, alarms, and trackers can help reduce costs",
                ],
            },
            {
                "id": "who-is-it-for",
                "heading": f"Who Is {kw_title} Suitable For",
                "content": (
                    f"{kw_title} comparison is suitable for any driver looking to find the right "
                    f"policy at a competitive price. This includes learner drivers and newly passed "
                    f"motorists shopping for their first policy, experienced drivers approaching renewal "
                    f"who want to check they are getting a fair deal, drivers who have recently changed "
                    f"vehicle or moved to a new area, and anyone whose circumstances have changed — such "
                    f"as adding a named driver or changing their annual mileage. Comparing quotes helps "
                    f"ensure you are aware of the full range of car insurance options available."
                ),
            },
            build_how_to_compare_section(keyword, kw_title),
            {
                "id": "tips-to-reduce-cost",
                "heading": f"Tips To Help Reduce Your {kw_title} Premium",
                "content": f"While the cost of {keyword} depends on your individual circumstances, there are several steps that may help you secure a more competitive quote.",
                "bullets": [
                    "Compare quotes before your renewal date — do not auto-renew without checking alternatives",
                    "Consider a telematics (black box) policy if you are a safe driver — these reward good driving behaviour with lower premiums",
                    "Build up your no-claims discount — each claim-free year can earn significant savings",
                    "Increase your voluntary excess — a higher excess may lower your premium, but ensure you can afford it if you need to claim",
                    "Reduce your annual mileage where possible — lower mileage can mean lower risk and lower premiums",
                    "Invest in approved security devices — Thatcham-approved alarms and trackers can help reduce your premium",
                ],
            },
            build_cta_section(keyword, kw_title, vertical_slug),
        ],
        "faq": [
            {
                "question": f"What does {keyword} cover?",
                "answer": (
                    f"Car insurance covers you financially if your vehicle is involved in an accident, "
                    f"stolen, or damaged. The level of cover depends on your policy type: third party "
                    f"only covers damage to others, third party fire and theft adds protection if your "
                    f"car is stolen or catches fire, and comprehensive covers damage to your own vehicle "
                    f"as well. Many policies also include extras like windscreen cover, courtesy car, "
                    f"and breakdown assistance."
                ),
            },
            {
                "question": f"Is {keyword} a legal requirement?",
                "answer": (
                    f"Yes. Car insurance is a legal requirement in the UK. You must have at least third "
                    f"party cover to drive on public roads. Driving without insurance is a criminal "
                    f"offence that can result in a fixed penalty, points on your licence, or having "
                    f"your vehicle seized. Even if your car is kept off the road, you need either "
                    f"insurance or a SORN (Statutory Off Road Notification)."
                ),
            },
            {
                "question": f"How much does {keyword} cost?",
                "answer": (
                    f"The cost of car insurance varies widely depending on your age, driving experience, "
                    f"vehicle type, postcode, and claims history. Younger drivers and those with high-"
                    f"performance vehicles typically pay more. Comparing quotes from multiple providers "
                    f"is one of the best ways to find a competitive price for your circumstances."
                ),
            },
            {
                "question": f"How can I build up a no-claims discount?",
                "answer": (
                    f"A no-claims discount (NCD) builds up for each consecutive year you hold a car "
                    f"insurance policy without making a claim. Most insurers offer increasing discounts "
                    f"for each claim-free year, typically up to five years. Some providers offer the "
                    f"option to protect your NCD for an additional cost, meaning one claim will not "
                    f"reset your discount."
                ),
            },
            build_comparison_faq(keyword),
        ],
        "compliance": COMPLIANCE,
    }


# -----------------------------------------------
# Home Insurance
# -----------------------------------------------
def build_home_insurance_page(keyword, url_pattern, kw_title, vertical_title, vertical_slug):
    return {
        "keyword": keyword,
        "url": url_pattern,
        "title": build_title(kw_title, vertical_title),
        "description": f"Compare {keyword} quotes from a panel of UK home insurance providers. Explore buildings cover, contents cover, and combined policies to protect your home with MySupermarketCompare.",
        "h1": f"Compare {kw_title} Quotes",
        "sections": [
            {
                "id": "introduction",
                "heading": None,
                "content": (
                    f"Comparing {keyword} quotes helps you find the right level of protection for "
                    f"your property and belongings. Whether you need buildings insurance, contents "
                    f"insurance, or a combined policy, using a comparison service lets you review "
                    f"multiple quotes from UK home insurers side by side. MySupermarketCompare works "
                    f"with Quotezone to search across a wide panel of providers, helping you compare "
                    f"{keyword} options and find cover that suits your home and budget."
                ),
            },
            {
                "id": "how-it-works",
                "heading": f"How {kw_title} Works",
                "content": (
                    f"Home insurance is designed to protect your property and possessions against "
                    f"damage, theft, and other risks. Buildings insurance covers the structure of your "
                    f"home — walls, roof, floors, and permanent fixtures — against events like fire, "
                    f"flood, storm damage, and subsidence. Contents insurance covers your personal "
                    f"belongings inside the home, including furniture, electronics, clothing, and "
                    f"valuables. Many homeowners choose a combined buildings and contents policy for "
                    f"comprehensive protection. Comparing {keyword} quotes helps you see how "
                    f"different providers structure their policies and what is included."
                ),
            },
            {
                "id": "cost-factors",
                "heading": f"What Affects The Cost Of {kw_title}",
                "content": f"Home insurers consider several factors when calculating your {keyword} premium. Understanding these can help you manage costs effectively.",
                "bullets": [
                    "Your property type — detached houses, flats, and older buildings each carry different risk profiles",
                    "The rebuild cost of your home — this is the cost to rebuild the property from scratch, not the market value",
                    "Your location and flood risk — properties in flood-prone or high-crime areas may cost more to insure",
                    "Your claims history — previous claims can increase your premium",
                    "The total value of your contents — higher-value belongings mean higher premiums",
                    "Security measures in place — burglar alarms, window locks, and deadlocks can help reduce costs",
                    "Your voluntary excess — a higher excess typically means a lower premium",
                ],
            },
            {
                "id": "who-is-it-for",
                "heading": f"Who Is {kw_title} Suitable For",
                "content": (
                    f"{kw_title} comparison is suitable for homeowners, landlords, and tenants who "
                    f"want to protect their property or belongings. This includes first-time buyers "
                    f"arranging cover as part of their mortgage, existing homeowners approaching "
                    f"renewal who want to check for a better deal, tenants looking for contents "
                    f"insurance to protect their personal possessions, and landlords needing "
                    f"specialist buildings cover. Comparing quotes ensures you are aware of the "
                    f"range of policies and prices available for your circumstances."
                ),
            },
            build_how_to_compare_section(keyword, kw_title),
            {
                "id": "tips-to-reduce-cost",
                "heading": f"Tips To Help Reduce Your {kw_title} Premium",
                "content": f"While the cost of {keyword} depends on your individual circumstances, there are several steps that may help you secure a more competitive quote.",
                "bullets": [
                    "Bundle buildings and contents insurance together — combined policies are often cheaper than buying separately",
                    "Improve your home security — fitting British Standard locks, a burglar alarm, and window locks can reduce premiums",
                    "Increase your voluntary excess — a higher excess typically lowers your premium, but make sure you can afford it",
                    "Fit accredited locks and security devices — insurers may offer discounts for Sold Secure or British Standard rated products",
                    "Get an accurate rebuild cost — use the Building Cost Information Service (BCIS) calculator to avoid over-insuring",
                    "Pay annually rather than monthly — monthly payments often include interest charges",
                ],
            },
            build_cta_section(keyword, kw_title, vertical_slug),
        ],
        "faq": [
            {
                "question": f"What does {keyword} cover?",
                "answer": (
                    f"Home insurance typically covers your property (buildings insurance) and your "
                    f"personal belongings (contents insurance). Buildings cover protects the structure "
                    f"of your home against fire, flood, storm, and subsidence. Contents cover protects "
                    f"items inside your home such as furniture, electronics, and valuables against "
                    f"theft, damage, and accidental loss. You can buy them separately or as a combined "
                    f"policy."
                ),
            },
            {
                "question": f"Is {keyword} a legal requirement?",
                "answer": (
                    f"No, home insurance is not a legal requirement in the UK. However, if you have "
                    f"a mortgage, your lender will almost certainly require you to have buildings "
                    f"insurance as a condition of the loan. Contents insurance is always optional but "
                    f"is strongly recommended to protect your personal belongings."
                ),
            },
            {
                "question": f"How much does {keyword} cost?",
                "answer": (
                    f"The cost of home insurance depends on factors including your property type, "
                    f"location, rebuild cost, contents value, claims history, and security measures. "
                    f"Properties in flood-risk areas or high-crime postcodes typically cost more to "
                    f"insure. Comparing quotes from multiple providers helps you find the most "
                    f"competitive price for your situation."
                ),
            },
            {
                "question": f"Does {keyword} cover subsidence?",
                "answer": (
                    f"Most buildings insurance policies include cover for subsidence, heave, and "
                    f"landslip as standard. However, if your property has a history of subsidence, "
                    f"you may find it harder to get cover or face higher premiums and excesses. "
                    f"Always check the policy details and any exclusions before purchasing."
                ),
            },
            build_comparison_faq(keyword),
        ],
        "compliance": COMPLIANCE,
    }


# -----------------------------------------------
# Van Insurance
# -----------------------------------------------
def build_van_insurance_page(keyword, url_pattern, kw_title, vertical_title, vertical_slug):
    return {
        "keyword": keyword,
        "url": url_pattern,
        "title": build_title(kw_title, vertical_title),
        "description": f"Compare {keyword} quotes from a panel of UK van insurance providers. Whether you use your van for business, courier work, or personal use, find the right cover with MySupermarketCompare.",
        "h1": f"Compare {kw_title} Quotes",
        "sections": [
            {
                "id": "introduction",
                "heading": None,
                "content": (
                    f"Comparing {keyword} quotes can help you find the right cover for how you "
                    f"use your van. Whether you drive a small panel van for personal errands, a "
                    f"large commercial vehicle for business deliveries, or work as a courier, a "
                    f"comparison service lets you review policies from multiple UK van insurers in "
                    f"one place. MySupermarketCompare works with Quotezone to search across a wide "
                    f"panel of providers, helping you compare {keyword} options tailored to your "
                    f"use type."
                ),
            },
            {
                "id": "how-it-works",
                "heading": f"How {kw_title} Works",
                "content": (
                    f"Van insurance works similarly to car insurance but is tailored to the way vans "
                    f"are used. Policies are typically categorised by use class: social only (personal "
                    f"use), social and commuting, carriage of own goods (for tradespeople), and "
                    f"hire and reward (for courier and delivery drivers). The correct use class is "
                    f"essential — using your van for business without the right cover could invalidate "
                    f"your policy. As with car insurance, you can choose between third party only, "
                    f"third party fire and theft, or comprehensive cover. Comparing {keyword} quotes "
                    f"helps you find the right policy for your specific use case."
                ),
            },
            {
                "id": "cost-factors",
                "heading": f"What Affects The Cost Of {kw_title}",
                "content": f"Van insurers assess several factors when calculating your {keyword} premium. Understanding these can help you manage your costs.",
                "bullets": [
                    "Your use type — social, business, or courier/hire-and-reward use each carry different risk levels and premiums",
                    "Your van's payload capacity and size — larger, heavier vans typically cost more to insure",
                    "Your annual mileage — higher mileage increases risk and premium cost",
                    "Your driving experience and age — younger or less experienced drivers pay more",
                    "Where you park your van overnight — secure off-street parking or a locked garage can reduce premiums",
                    "Any modifications to your van — non-standard modifications can increase costs",
                    "Your claims history — a clean record helps keep premiums down",
                ],
            },
            {
                "id": "who-is-it-for",
                "heading": f"Who Is {kw_title} Suitable For",
                "content": (
                    f"{kw_title} comparison is suitable for anyone who drives a van and needs "
                    f"the right level of cover. This includes tradespeople who use their van for "
                    f"work, courier and delivery drivers who need hire-and-reward cover, small "
                    f"business owners running a fleet of vans, and private individuals who use a "
                    f"van for personal transport. Comparing quotes ensures you get the correct use "
                    f"class at a competitive price, whether you need a single van policy or "
                    f"multi-van cover."
                ),
            },
            build_how_to_compare_section(keyword, kw_title),
            {
                "id": "tips-to-reduce-cost",
                "heading": f"Tips To Help Reduce Your {kw_title} Premium",
                "content": f"While the cost of {keyword} depends on your circumstances, there are several steps that may help you secure a more competitive quote.",
                "bullets": [
                    "Declare the correct use class — being honest about how you use your van ensures valid cover and avoids overpaying",
                    "Park in a secure location overnight — a locked garage or secure compound can reduce theft risk and premiums",
                    "Consider a telematics policy — these reward safe driving behaviour with lower premiums",
                    "Look into fleet or multi-van discounts — if you insure more than one van, bundling can save money",
                    "Fit approved locks and security — Thatcham-approved locks and tracking devices can reduce premiums",
                    "Compare quotes before your renewal date — do not auto-renew without checking alternatives",
                ],
            },
            build_cta_section(keyword, kw_title, vertical_slug),
        ],
        "faq": [
            {
                "question": f"What does {keyword} cover?",
                "answer": (
                    f"Van insurance covers your van against damage, theft, and third party liability, "
                    f"much like car insurance. The level of cover depends on your policy type: third "
                    f"party only, third party fire and theft, or comprehensive. Some policies also "
                    f"cover tools and equipment stored in the van, goods in transit, and breakdown "
                    f"assistance. The right cover depends on how you use your van."
                ),
            },
            {
                "question": f"Is {keyword} a legal requirement?",
                "answer": (
                    f"Yes. Like car insurance, van insurance is a legal requirement in the UK. You "
                    f"must have at least third party cover to drive your van on public roads. "
                    f"Driving without insurance is a criminal offence. If you use your van for "
                    f"business purposes, you must also ensure your policy covers commercial use."
                ),
            },
            {
                "question": f"How much does {keyword} cost?",
                "answer": (
                    f"The cost of van insurance depends on your use type, van size, driving "
                    f"experience, location, and claims history. Courier and hire-and-reward policies "
                    f"tend to cost more than social-only cover due to higher mileage and risk. "
                    f"Comparing quotes from multiple providers is the best way to find a competitive "
                    f"price for your specific needs."
                ),
            },
            {
                "question": f"Do I need separate courier cover?",
                "answer": (
                    f"Yes, if you use your van for courier or delivery work, you need a hire-and-"
                    f"reward policy. Standard social or business van insurance does not cover paid "
                    f"delivery work. Using your van for courier work without the correct cover could "
                    f"invalidate your policy and leave you uninsured. Always declare your use type "
                    f"accurately when getting quotes."
                ),
            },
            build_comparison_faq(keyword),
        ],
        "compliance": COMPLIANCE,
    }


# -----------------------------------------------
# Motorbike Insurance
# -----------------------------------------------
def build_motorbike_insurance_page(keyword, url_pattern, kw_title, vertical_title, vertical_slug):
    return {
        "keyword": keyword,
        "url": url_pattern,
        "title": build_title(kw_title, vertical_title),
        "description": f"Compare {keyword} quotes from a panel of UK motorbike insurance providers. Whether you ride a 125cc commuter or a high-performance sportsbike, find the right cover with MySupermarketCompare.",
        "h1": f"Compare {kw_title} Quotes",
        "sections": [
            {
                "id": "introduction",
                "heading": None,
                "content": (
                    f"Comparing {keyword} quotes helps you find cover that suits your bike and "
                    f"riding style at a competitive price. Whether you ride a 125cc commuter, a "
                    f"touring bike, or a high-performance sportsbike, a comparison service lets you "
                    f"review quotes from multiple UK motorbike insurers in one place. "
                    f"MySupermarketCompare works with Quotezone to search across a wide panel of "
                    f"providers, making it easy to compare {keyword} options."
                ),
            },
            {
                "id": "how-it-works",
                "heading": f"How {kw_title} Works",
                "content": (
                    f"Motorbike insurance protects you financially if your bike is damaged, stolen, "
                    f"or involved in an accident. As with car insurance, there are three main cover "
                    f"levels: third party only (the legal minimum), third party fire and theft, and "
                    f"fully comprehensive. The right level depends on your bike's value, how you use "
                    f"it, and your budget. Many motorbike policies also offer extras such as helmet "
                    f"and leathers cover, breakdown assistance, and pillion passenger cover. Comparing "
                    f"{keyword} quotes lets you see what each provider offers at each price point."
                ),
            },
            {
                "id": "cost-factors",
                "heading": f"What Affects The Cost Of {kw_title}",
                "content": f"Motorbike insurers assess several factors when calculating your {keyword} premium. Understanding these can help you find ways to manage costs.",
                "bullets": [
                    "Your bike's engine size (cc) — higher-powered bikes cost more to insure",
                    "Your age and riding experience — younger and less experienced riders typically pay higher premiums",
                    "Your bike's value and desirability — high-value or commonly stolen models attract higher premiums",
                    "Where and how you store your bike — garage storage is cheaper than keeping it on the street",
                    "Any modifications — aftermarket exhausts, performance upgrades, or cosmetic changes can increase costs",
                    "Your claims history — a claim-free record helps keep premiums down",
                    "Your annual mileage — lower mileage generally means lower premiums",
                ],
            },
            {
                "id": "who-is-it-for",
                "heading": f"Who Is {kw_title} Suitable For",
                "content": (
                    f"{kw_title} comparison is suitable for any rider looking for the right cover. "
                    f"This includes CBT holders and new riders looking for their first policy, "
                    f"experienced riders approaching renewal who want to check for a better deal, "
                    f"riders who have recently upgraded their bike or changed their riding habits, "
                    f"and commuters looking for cost-effective cover for daily use. Comparing quotes "
                    f"helps ensure you find a policy that matches your bike, riding experience, and "
                    f"budget."
                ),
            },
            build_how_to_compare_section(keyword, kw_title),
            {
                "id": "tips-to-reduce-cost",
                "heading": f"Tips To Help Reduce Your {kw_title} Premium",
                "content": f"While the cost of {keyword} depends on your individual circumstances, there are several steps that may help you secure a more competitive quote.",
                "bullets": [
                    "Complete an advanced riding course — qualifications like IAM RoadSmart or ERS can earn discounts with many insurers",
                    "Invest in quality security — a Sold Secure chain, disc lock, or ground anchor can significantly reduce premiums",
                    "Store your bike in a locked garage — secure storage reduces theft risk and lowers your premium",
                    "Limit modifications — standard bikes are generally cheaper to insure than modified ones",
                    "Consider an agreed value policy — this guarantees a payout based on your bike's true value if it is written off",
                    "Compare quotes before your renewal date — do not auto-renew without checking alternatives",
                ],
            },
            build_cta_section(keyword, kw_title, vertical_slug),
        ],
        "faq": [
            {
                "question": f"What does {keyword} cover?",
                "answer": (
                    f"Motorbike insurance covers your bike against damage, theft, and third party "
                    f"liability. Third party only is the legal minimum and covers damage to others. "
                    f"Third party fire and theft adds cover if your bike is stolen or damaged by fire. "
                    f"Comprehensive covers all of the above plus damage to your own bike. Many "
                    f"policies also offer optional extras such as helmet and leathers cover, breakdown "
                    f"assistance, and legal expenses."
                ),
            },
            {
                "question": f"Is {keyword} a legal requirement?",
                "answer": (
                    f"Yes. Motorbike insurance is a legal requirement in the UK. You must have at "
                    f"least third party cover to ride on public roads. This applies to all "
                    f"motorcycles, including mopeds and scooters. Riding without insurance is a "
                    f"criminal offence that can result in a fine, penalty points, or seizure of "
                    f"your bike."
                ),
            },
            {
                "question": f"How much does {keyword} cost?",
                "answer": (
                    f"The cost of motorbike insurance varies depending on your bike's engine size, "
                    f"your age and experience, where you live, and your claims history. Smaller bikes "
                    f"(125cc) are generally cheapest to insure, while high-performance sportsbikes "
                    f"attract the highest premiums. Comparing quotes helps you find the best price "
                    f"for your specific bike and circumstances."
                ),
            },
            {
                "question": f"Can I get {keyword} with a CBT?",
                "answer": (
                    f"Yes, you can get motorbike insurance with a CBT (Compulsory Basic Training) "
                    f"certificate. CBT allows you to ride bikes up to 125cc with L-plates. Some "
                    f"insurers specialise in cover for CBT holders and new riders, though premiums "
                    f"may be higher due to limited riding experience. Completing your full motorcycle "
                    f"test can help reduce costs."
                ),
            },
            build_comparison_faq(keyword),
        ],
        "compliance": COMPLIANCE,
    }


# -----------------------------------------------
# Pet Insurance
# -----------------------------------------------
def build_pet_insurance_page(keyword, url_pattern, kw_title, vertical_title, vertical_slug):
    return {
        "keyword": keyword,
        "url": url_pattern,
        "title": build_title(kw_title, vertical_title),
        "description": f"Compare {keyword} quotes from a panel of UK pet insurance providers. Explore cover levels, vet fee limits, and policy options to protect your pet with MySupermarketCompare.",
        "h1": f"Compare {kw_title} Quotes",
        "sections": [
            {
                "id": "introduction",
                "heading": None,
                "content": (
                    f"Comparing {keyword} quotes helps you find the right level of cover for your "
                    f"pet at a price that suits your budget. Whether you have a dog, cat, or other "
                    f"pet, vet bills can be expensive and unexpected. A comparison service lets you "
                    f"review policies from multiple UK pet insurers side by side. MySupermarketCompare "
                    f"works with Quotezone to search across a wide panel of providers, making it easy "
                    f"to compare {keyword} options and find the cover your pet needs."
                ),
            },
            {
                "id": "how-it-works",
                "heading": f"How {kw_title} Works",
                "content": (
                    f"Pet insurance helps cover the cost of veterinary treatment if your pet becomes "
                    f"ill or is injured. There are four main types of cover: accident only (the most "
                    f"basic), time-limited (covers each condition for 12 months), maximum benefit "
                    f"(a set amount per condition with no time limit), and lifetime (renews the full "
                    f"benefit amount each year). Lifetime cover is the most comprehensive option and "
                    f"is particularly important for pets with ongoing or chronic conditions. Comparing "
                    f"{keyword} quotes lets you see how different providers structure their policies "
                    f"and what vet fee limits they offer."
                ),
            },
            {
                "id": "cost-factors",
                "heading": f"What Affects The Cost Of {kw_title}",
                "content": f"Pet insurers consider several factors when calculating your {keyword} premium. Understanding these can help you find value for money.",
                "bullets": [
                    "Your pet's breed — some breeds are more prone to hereditary conditions and cost more to insure",
                    "Your pet's age — older pets typically have higher premiums due to increased health risks",
                    "Any pre-existing conditions — most policies exclude conditions your pet already has",
                    "The level of cover you choose — lifetime cover costs more than accident-only or time-limited policies",
                    "The vet fee limit — higher annual limits mean higher premiums but better protection",
                    "Your excess amount — a higher excess reduces your premium but means you pay more per claim",
                    "Your location — vet costs vary by region, which affects premiums",
                ],
            },
            {
                "id": "who-is-it-for",
                "heading": f"Who Is {kw_title} Suitable For",
                "content": (
                    f"{kw_title} comparison is suitable for any pet owner who wants to protect "
                    f"against unexpected vet bills. This includes new pet owners looking for their "
                    f"first policy, existing policyholders approaching renewal who want to check for "
                    f"a better deal, owners of breeds with known health risks who need comprehensive "
                    f"cover, and multi-pet households looking for the best value across several "
                    f"animals. Comparing quotes helps you understand the range of cover levels, "
                    f"vet fee limits, and prices available."
                ),
            },
            build_how_to_compare_section(keyword, kw_title),
            {
                "id": "tips-to-reduce-cost",
                "heading": f"Tips To Help Reduce Your {kw_title} Premium",
                "content": f"While the cost of {keyword} depends on your pet and circumstances, there are several steps that may help you find better value.",
                "bullets": [
                    "Insure your pet when they are young — premiums are lower and fewer conditions will be excluded",
                    "Consider lifetime cover for long-term value — it costs more upfront but covers ongoing conditions year after year",
                    "Compare vet fee limits carefully — a higher limit costs more per month but provides better protection if your pet needs expensive treatment",
                    "Look for multi-pet discounts — many providers offer savings if you insure more than one pet on the same policy",
                    "Weigh up annual vs monthly payments — paying annually often works out cheaper due to interest charges on monthly plans",
                    "Review your policy annually at renewal — your pet's needs may change and a different policy could offer better value",
                ],
            },
            build_cta_section(keyword, kw_title, vertical_slug),
        ],
        "faq": [
            {
                "question": f"What does {keyword} cover?",
                "answer": (
                    f"Pet insurance covers the cost of veterinary treatment if your pet is ill or "
                    f"injured. Depending on your policy type, it may cover accidents, illnesses, "
                    f"surgery, medication, and ongoing conditions. Some policies also include extras "
                    f"like third party liability (for dogs), lost pet advertising, and holiday "
                    f"cancellation cover. The level of cover depends on whether you choose accident "
                    f"only, time-limited, maximum benefit, or lifetime cover."
                ),
            },
            {
                "question": f"Is {keyword} a legal requirement?",
                "answer": (
                    f"No, pet insurance is not a legal requirement in the UK. However, vet bills can "
                    f"be very expensive — complex treatments can run into thousands of pounds. Pet "
                    f"insurance gives you peace of mind that you can afford the best treatment for "
                    f"your pet without facing unexpected financial strain."
                ),
            },
            {
                "question": f"How much does {keyword} cost?",
                "answer": (
                    f"The cost of pet insurance varies depending on your pet's breed, age, and the "
                    f"level of cover you choose. For example, insuring a young crossbreed dog on a "
                    f"basic policy will typically cost less than insuring an older pedigree breed on "
                    f"lifetime cover. Comparing quotes from multiple providers helps you find the "
                    f"best price for the cover level your pet needs."
                ),
            },
            {
                "question": f"Are pre-existing conditions covered?",
                "answer": (
                    f"Most pet insurance policies do not cover pre-existing conditions — that is, "
                    f"any illness or injury your pet had before the policy started. This is one of "
                    f"the main reasons to insure your pet when they are young and healthy. Some "
                    f"specialist policies may offer limited cover for pre-existing conditions, but "
                    f"these are rare and typically more expensive."
                ),
            },
            build_comparison_faq(keyword),
        ],
        "compliance": COMPLIANCE,
    }


# -----------------------------------------------
# Travel Insurance
# -----------------------------------------------
def build_travel_insurance_page(keyword, url_pattern, kw_title, vertical_title, vertical_slug):
    return {
        "keyword": keyword,
        "url": url_pattern,
        "title": build_title(kw_title, vertical_title),
        "description": f"Compare {keyword} quotes from a panel of UK travel insurance providers. Explore medical cover, cancellation protection, and baggage cover for your trip with MySupermarketCompare.",
        "h1": f"Compare {kw_title} Quotes",
        "sections": [
            {
                "id": "introduction",
                "heading": None,
                "content": (
                    f"Comparing {keyword} quotes helps you find the right level of protection "
                    f"for your trip. Whether you are planning a short city break, a long-haul "
                    f"holiday, or a business trip, travel insurance provides cover for unexpected "
                    f"events like medical emergencies, cancellations, and lost baggage. "
                    f"MySupermarketCompare works with Quotezone to search across a wide panel of UK "
                    f"travel insurance providers, making it easy to compare {keyword} options "
                    f"and find the cover you need before you travel."
                ),
            },
            {
                "id": "how-it-works",
                "heading": f"How {kw_title} Works",
                "content": (
                    f"Travel insurance protects you financially against unexpected events before "
                    f"and during your trip. Key areas of cover typically include emergency medical "
                    f"treatment abroad, trip cancellation or curtailment, lost or stolen baggage, "
                    f"travel delays, personal liability, and legal expenses. You can buy single-trip "
                    f"cover for one holiday or annual multi-trip cover if you travel frequently. "
                    f"Some policies also offer specialist cover for winter sports, adventure "
                    f"activities, and cruise holidays. Comparing {keyword} quotes helps you "
                    f"find a policy that matches your destination, trip type, and budget."
                ),
            },
            {
                "id": "cost-factors",
                "heading": f"What Affects The Cost Of {kw_title}",
                "content": f"Travel insurers consider several factors when calculating your {keyword} premium. Understanding these can help you find the right cover at a good price.",
                "bullets": [
                    "Your destination — higher-risk regions or countries with expensive healthcare (like the USA) cost more to cover",
                    "Your trip duration — longer trips carry more risk and higher premiums",
                    "Your age — older travellers may face higher premiums due to increased health risks",
                    "Any pre-existing medical conditions — these must be declared and may increase your premium or require specialist cover",
                    "Planned activities — adventure sports, skiing, or scuba diving may need additional cover",
                    "The value of baggage and personal belongings you are taking",
                    "The level of cover you choose — basic, standard, or comprehensive",
                ],
            },
            {
                "id": "who-is-it-for",
                "heading": f"Who Is {kw_title} Suitable For",
                "content": (
                    f"{kw_title} comparison is suitable for anyone planning a trip abroad or within "
                    f"the UK. This includes holidaymakers looking for single-trip cover, frequent "
                    f"travellers who could save with an annual multi-trip policy, families and groups "
                    f"looking for the best value, travellers with pre-existing medical conditions who "
                    f"need specialist cover, and adventure travellers who need activity-specific "
                    f"protection. Comparing quotes ensures you find the right level of cover for your "
                    f"specific trip and circumstances."
                ),
            },
            build_how_to_compare_section(keyword, kw_title),
            {
                "id": "tips-to-reduce-cost",
                "heading": f"Tips To Help Reduce Your {kw_title} Premium",
                "content": f"While the cost of {keyword} depends on your trip and personal circumstances, there are several steps that may help you find better value.",
                "bullets": [
                    "Choose between single-trip and annual multi-trip — if you travel more than twice a year, an annual policy is usually cheaper",
                    "Declare all pre-existing medical conditions upfront — failing to disclose could invalidate your entire policy",
                    "Check if you have a valid GHIC or EHIC — this provides access to state healthcare in Europe but is not a substitute for travel insurance",
                    "Only add activity cover you actually need — unnecessary extras increase your premium",
                    "Compare excess amounts — a lower excess means you pay less per claim but your premium may be higher",
                    "Buy your travel insurance as soon as you book — this gives you cancellation cover from day one",
                ],
            },
            build_cta_section(keyword, kw_title, vertical_slug),
        ],
        "faq": [
            {
                "question": f"What does {keyword} cover?",
                "answer": (
                    f"Travel insurance typically covers emergency medical treatment abroad, trip "
                    f"cancellation or curtailment, lost or stolen baggage, travel delays, personal "
                    f"liability, and legal expenses. The exact cover depends on your policy level "
                    f"and any optional extras you add. Always check what is included before you buy."
                ),
            },
            {
                "question": f"Is {keyword} a legal requirement?",
                "answer": (
                    f"No, travel insurance is not a legal requirement. However, it is strongly "
                    f"recommended for any trip, especially abroad. Medical treatment overseas can be "
                    f"extremely expensive — a hospital stay in the USA, for example, can cost tens of "
                    f"thousands of pounds. Without travel insurance, you would need to pay these "
                    f"costs yourself."
                ),
            },
            {
                "question": f"How much does {keyword} cost?",
                "answer": (
                    f"The cost of travel insurance depends on your destination, trip duration, age, "
                    f"health, and the level of cover you choose. A basic European single-trip policy "
                    f"can cost relatively little, while comprehensive worldwide cover for an extended "
                    f"trip will cost more. Comparing quotes from multiple providers helps you find "
                    f"the best value."
                ),
            },
            {
                "question": f"Are pre-existing medical conditions covered?",
                "answer": (
                    f"Many travel insurance providers can cover pre-existing medical conditions, but "
                    f"you must declare them when getting a quote. Failing to disclose a pre-existing "
                    f"condition could invalidate your policy entirely. Some conditions may be covered "
                    f"at no extra cost, while others may require an additional premium. Specialist "
                    f"travel insurance providers cater specifically to travellers with medical "
                    f"conditions."
                ),
            },
            build_comparison_faq(keyword),
        ],
        "compliance": COMPLIANCE,
    }


# -----------------------------------------------
# Bicycle Insurance
# -----------------------------------------------
def build_bicycle_insurance_page(keyword, url_pattern, kw_title, vertical_title, vertical_slug):
    return {
        "keyword": keyword,
        "url": url_pattern,
        "title": build_title(kw_title, vertical_title),
        "description": f"Compare {keyword} quotes from a panel of UK bicycle insurance providers. Cover your bike against theft, accidental damage, and more with MySupermarketCompare.",
        "h1": f"Compare {kw_title} Quotes",
        "sections": [
            {
                "id": "introduction",
                "heading": None,
                "content": (
                    f"Comparing {keyword} quotes helps you find the right cover to protect your "
                    f"bike against theft, accidental damage, and other risks. Whether you ride a "
                    f"road bike, e-bike, mountain bike, or use your bicycle for daily commuting, "
                    f"dedicated cycle insurance can provide better protection than relying on home "
                    f"contents cover alone. MySupermarketCompare works with Quotezone to search "
                    f"across a wide panel of UK bicycle insurance providers, making it easy to "
                    f"compare {keyword} options."
                ),
            },
            {
                "id": "how-it-works",
                "heading": f"How {kw_title} Works",
                "content": (
                    f"Bicycle insurance provides specialist cover designed specifically for cyclists. "
                    f"Policies typically cover theft (at home and away), accidental damage, "
                    f"third party liability, personal accident cover, and accessories. Unlike home "
                    f"contents insurance, which may have limited cover for bikes away from the home "
                    f"or high excesses, dedicated bicycle insurance is tailored to the risks "
                    f"cyclists face. Some policies also cover race entry fees, cycling abroad, and "
                    f"bike hire while yours is being repaired. Comparing {keyword} quotes lets you "
                    f"see what each provider covers and at what price."
                ),
            },
            {
                "id": "cost-factors",
                "heading": f"What Affects The Cost Of {kw_title}",
                "content": f"Bicycle insurers consider several factors when calculating your {keyword} premium. Understanding these can help you find the right cover at a good price.",
                "bullets": [
                    "Your bike's value — more expensive bikes cost more to insure, especially high-end road bikes and e-bikes",
                    "Your bike type — road bikes, e-bikes, and mountain bikes each carry different risk profiles",
                    "Theft risk in your postcode — areas with higher bike theft rates attract higher premiums",
                    "The value of accessories — lights, GPS units, and other accessories add to the total insured value",
                    "How you use your bike — commuting, leisure, and competitive use may affect pricing",
                    "Where you store your bike — secure indoor storage or a locked shed is better than outdoor storage",
                ],
            },
            {
                "id": "who-is-it-for",
                "heading": f"Who Is {kw_title} Suitable For",
                "content": (
                    f"{kw_title} comparison is suitable for any cyclist who wants to protect their "
                    f"bike and riding investment. This includes daily commuters who rely on their bike "
                    f"for transport, road cyclists and mountain bikers with high-value bikes, e-bike "
                    f"owners who want cover for their battery and motor, and anyone who finds that "
                    f"their home contents insurance does not provide adequate cycle cover. Comparing "
                    f"quotes helps you find a policy that covers your bike's full value and the "
                    f"risks you face."
                ),
            },
            build_how_to_compare_section(keyword, kw_title),
            {
                "id": "tips-to-reduce-cost",
                "heading": f"Tips To Help Reduce Your {kw_title} Premium",
                "content": f"While the cost of {keyword} depends on your bike and circumstances, there are several steps that may help you keep costs down.",
                "bullets": [
                    "Use an approved lock — Sold Secure rated locks (Gold or Diamond) are required by most insurers and can reduce premiums",
                    "Register your bike with BikeRegister — this national database helps police recover stolen bikes and many insurers offer discounts for registered bikes",
                    "Photograph your bike and accessories — keeping a record of serial numbers and receipts supports any claim",
                    "Store your bike securely indoors — a locked garage or inside your home is safer than a shed or outdoor storage",
                    "Check your home contents policy for gaps — you may already have some cover but with a high excess or low away-from-home limit",
                    "Compare quotes before your renewal date — do not auto-renew without checking alternatives",
                ],
            },
            build_cta_section(keyword, kw_title, vertical_slug),
        ],
        "faq": [
            {
                "question": f"What does {keyword} cover?",
                "answer": (
                    f"Bicycle insurance typically covers theft (at home and away from home), "
                    f"accidental damage, third party liability, personal accident, and accessories. "
                    f"Some policies also cover cycling abroad, race entry fee loss, and bike hire "
                    f"while yours is being repaired. The exact cover depends on your policy and "
                    f"provider."
                ),
            },
            {
                "question": f"Is {keyword} a legal requirement?",
                "answer": (
                    f"No, bicycle insurance is not a legal requirement in the UK. Unlike motor "
                    f"vehicles, there is no law requiring cyclists to have insurance. However, "
                    f"dedicated bicycle insurance provides valuable protection against theft and "
                    f"damage, especially for higher-value bikes that may not be adequately covered "
                    f"by home contents insurance."
                ),
            },
            {
                "question": f"How much does {keyword} cost?",
                "answer": (
                    f"The cost of bicycle insurance depends mainly on your bike's value, type, and "
                    f"where you live. An entry-level commuter bike will cost less to insure than a "
                    f"high-end carbon road bike or e-bike. Premiums are typically a percentage of "
                    f"your bike's value. Comparing quotes from multiple providers helps you find "
                    f"the best price for your level of cover."
                ),
            },
            {
                "question": f"Does my home contents insurance cover my bike?",
                "answer": (
                    f"Some home contents policies include cover for bicycles, but this is often "
                    f"limited. Common restrictions include low single-item limits, high excesses, "
                    f"limited or no cover away from the home, and no cover for accidental damage. "
                    f"If your bike is worth more than your home policy's single-item limit, or you "
                    f"frequently ride and lock up away from home, dedicated bicycle insurance is "
                    f"likely to provide better protection."
                ),
            },
            build_comparison_faq(keyword),
        ],
        "compliance": COMPLIANCE,
    }


# -----------------------------------------------
# Breakdown Cover
# -----------------------------------------------
def build_breakdown_cover_page(keyword, url_pattern, kw_title, vertical_title, vertical_slug):
    return {
        "keyword": keyword,
        "url": url_pattern,
        "title": build_title(kw_title, vertical_title),
        "description": f"Compare {keyword} quotes from a panel of UK breakdown cover providers. Explore roadside, recovery, home-start, and onward travel options with MySupermarketCompare.",
        "h1": f"Compare {kw_title} Quotes",
        "sections": [
            {
                "id": "introduction",
                "heading": None,
                "content": (
                    f"Comparing {keyword} quotes helps you find the right level of roadside "
                    f"assistance at a competitive price. Whether you need basic roadside help, "
                    f"full recovery to a garage, home-start cover, or onward travel, a comparison "
                    f"service lets you review policies from multiple UK breakdown providers in one "
                    f"place. MySupermarketCompare works with Quotezone to search across a wide panel "
                    f"of providers, making it easy to compare {keyword} options and find the "
                    f"protection you need."
                ),
            },
            {
                "id": "how-it-works",
                "heading": f"How {kw_title} Works",
                "content": (
                    f"Breakdown cover provides roadside assistance if your vehicle breaks down. "
                    f"There are several levels of cover: roadside assistance (a mechanic comes to "
                    f"you at the roadside), recovery (your vehicle is towed to a garage if it cannot "
                    f"be fixed at the roadside), home-start (cover if your vehicle breaks down at or "
                    f"near your home), and onward travel (alternative transport or accommodation if "
                    f"your vehicle cannot be repaired the same day). Some policies also cover European "
                    f"travel. Comparing {keyword} quotes lets you choose the right level of "
                    f"protection for your needs and budget."
                ),
            },
            {
                "id": "cost-factors",
                "heading": f"What Affects The Cost Of {kw_title}",
                "content": f"Breakdown providers consider several factors when pricing your {keyword} policy. Understanding these can help you choose the right level of cover.",
                "bullets": [
                    "The cover level you choose — roadside-only is cheapest while full recovery with onward travel costs more",
                    "Your vehicle's age — older vehicles may cost more to cover due to higher breakdown risk",
                    "Your annual mileage — higher mileage means more time on the road and higher risk",
                    "The number of callouts included — some policies limit callouts per year",
                    "Whether you choose personal or vehicle-based cover — personal cover protects you in any vehicle",
                ],
            },
            {
                "id": "who-is-it-for",
                "heading": f"Who Is {kw_title} Suitable For",
                "content": (
                    f"{kw_title} comparison is suitable for any driver who wants peace of mind "
                    f"on the road. This includes commuters who rely on their vehicle daily, drivers "
                    f"of older vehicles that may be more prone to breakdowns, families who want "
                    f"protection on long journeys, anyone who drives in rural areas where a breakdown "
                    f"could leave them stranded, and drivers who want personal cover that works in "
                    f"any vehicle they travel in. Comparing quotes helps you find the right level "
                    f"of cover without overpaying."
                ),
            },
            build_how_to_compare_section(keyword, kw_title),
            {
                "id": "tips-to-reduce-cost",
                "heading": f"Tips To Help Reduce Your {kw_title} Premium",
                "content": f"While the cost of {keyword} depends on the level of cover you need, there are several steps that may help you find better value.",
                "bullets": [
                    "Compare quotes before your renewal date — do not auto-renew without checking alternatives",
                    "Consider personal cover instead of vehicle cover — personal policies cover you in any vehicle, which can be better value if you drive multiple cars",
                    "Check if breakdown cover is already included with your car insurance — some motor policies include basic roadside assistance",
                    "Choose the right level of cover — if you mainly drive locally, roadside-only may be sufficient without paying for full recovery",
                    "Add extras selectively — only pay for European cover, home-start, or onward travel if you genuinely need them",
                    "Review your cover annually — your driving habits may change and a different level of cover could save money",
                ],
            },
            build_cta_section(keyword, kw_title, vertical_slug),
        ],
        "faq": [
            {
                "question": f"What does {keyword} cover?",
                "answer": (
                    f"Breakdown cover provides assistance if your vehicle breaks down. Basic "
                    f"roadside cover sends a mechanic to fix your vehicle at the roadside. Higher "
                    f"levels add recovery to a garage, home-start cover for breakdowns at home, "
                    f"and onward travel options including hire cars or accommodation. The exact "
                    f"cover depends on the policy level you choose."
                ),
            },
            {
                "question": f"Is {keyword} a legal requirement?",
                "answer": (
                    f"No, breakdown cover is not a legal requirement in the UK. It is an optional "
                    f"service that provides peace of mind and practical help if your vehicle breaks "
                    f"down. While you can call a mechanic or recovery service without a policy, "
                    f"the cost of a single callout can be more than an annual breakdown policy."
                ),
            },
            {
                "question": f"How much does {keyword} cost?",
                "answer": (
                    f"The cost of breakdown cover depends on the level of cover you choose. Basic "
                    f"roadside assistance is the cheapest option, while comprehensive cover including "
                    f"recovery, home-start, and onward travel costs more. Personal cover (which "
                    f"covers you in any vehicle) and vehicle-specific cover are priced differently. "
                    f"Comparing quotes helps you find the right balance of cover and cost."
                ),
            },
            {
                "question": f"What is the difference between personal and vehicle cover?",
                "answer": (
                    f"Vehicle-based breakdown cover protects a specific vehicle, regardless of who "
                    f"is driving it. Personal cover protects you as a driver in any vehicle you "
                    f"travel in — whether you are driving or a passenger. Personal cover can be "
                    f"better value if you regularly drive different vehicles or want cover when "
                    f"travelling with others."
                ),
            },
            build_comparison_faq(keyword),
        ],
        "compliance": COMPLIANCE,
    }


# -----------------------------------------------
# Template dispatch
# -----------------------------------------------
TEMPLATES = {
    "car-insurance": build_car_insurance_page,
    "home-insurance": build_home_insurance_page,
    "van-insurance": build_van_insurance_page,
    "motorbike-insurance": build_motorbike_insurance_page,
    "pet-insurance": build_pet_insurance_page,
    "travel-insurance": build_travel_insurance_page,
    "bicycle-insurance": build_bicycle_insurance_page,
    "breakdown-cover": build_breakdown_cover_page,
}

builder = TEMPLATES.get(vertical_slug)
if builder is None:
    print(f"ERROR: Unknown vertical '{vertical_slug}'. Known verticals: {', '.join(sorted(TEMPLATES.keys()))}", file=sys.stderr)
    sys.exit(1)

page = builder(keyword, url_pattern, kw_title, vertical_title, vertical_slug)
print(json.dumps(page, indent=2))
PYTHON_SCRIPT
