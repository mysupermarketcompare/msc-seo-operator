#!/bin/bash

# ===============================================
# Google Search Console Monitor
# ===============================================
# Queries the Google Search Console API for
# indexing status and search performance data.
#
# Replaces index-monitor.sh which scraped Google
# search results (fragile, risk of IP blocking).
#
# Outputs:
#   data/gsc-report.csv   — full performance data
#   data/index-report.csv — compatible with crawl
#                           budget controller
#
# Requires:
#   - Service account JSON at credentials/gsc-service-account.json
#   - Service account added as user in GSC property
#   - python3 with google-auth and requests
# ===============================================

WORKSPACE="$HOME/.openclaw/workspace/msc-seo"
CREDENTIALS="$WORKSPACE/credentials/gsc-service-account.json"

echo "======================================="
echo "Running Google Search Console monitor..."
echo "Time: $(date)"
echo "======================================="

# -----------------------------------------------
# Pre-flight: check credentials exist
# -----------------------------------------------
if [ ! -f "$CREDENTIALS" ]; then
  echo ""
  echo "GSC service account credentials not found."
  echo ""
  echo "Setup instructions:"
  echo ""
  echo "  1. Go to https://console.cloud.google.com/"
  echo "  2. Create or select a project"
  echo "  3. Enable the 'Google Search Console API'"
  echo "     (APIs & Services → Library → search 'Search Console API')"
  echo "  4. Create a service account:"
  echo "     (APIs & Services → Credentials → Create Credentials → Service Account)"
  echo "  5. Create a JSON key for the service account:"
  echo "     (Click service account → Keys → Add Key → Create new key → JSON)"
  echo "  6. Save the JSON key file to:"
  echo "     $CREDENTIALS"
  echo "  7. Add the service account email as a user in Google Search Console:"
  echo "     (Search Console → Settings → Users and permissions → Add user)"
  echo "     Permission level: Full"
  echo "     The email is in the JSON file under 'client_email'"
  echo ""
  echo "  mkdir -p $WORKSPACE/credentials"
  echo "  cp ~/Downloads/your-key-file.json $CREDENTIALS"
  echo ""
  echo "After setup, re-run this script."
  echo "======================================="

  # Write a stub index-report.csv so crawl-budget-controller.sh
  # doesn't fail on first run before GSC is configured
  mkdir -p "$WORKSPACE/data"
  if [ ! -f "$WORKSPACE/data/index-report.csv" ]; then
    echo "url,http_status,index_status" > "$WORKSPACE/data/index-report.csv"
    echo "Wrote empty index-report.csv (crawl budget will use defaults)"
  fi

  exit 0
fi

# -----------------------------------------------
# Run the GSC query via Python
# -----------------------------------------------
python3 << 'PYTHON_SCRIPT'
import json
import os
import sys
import glob
import csv
from datetime import datetime, timedelta

# -----------------------------------------------
# Configuration
# -----------------------------------------------
WORKSPACE = os.path.expanduser("~/.openclaw/workspace/msc-seo")
CREDENTIALS_PATH = os.path.join(WORKSPACE, "credentials", "gsc-service-account.json")
PAGES_DIR = os.path.expanduser("~/MSCINSURANCE-1/src/data/pages")
# Search Console domain property format required for API access
# Domain properties must use: sc-domain:example.com
# URL prefix properties use: https://example.com/
SITE_URL = "sc-domain:mysupermarketcompare.com"
GSC_REPORT = os.path.join(WORKSPACE, "data", "gsc-report.csv")
INDEX_REPORT = os.path.join(WORKSPACE, "data", "index-report.csv")

# -----------------------------------------------
# Step 1: Check dependencies
# -----------------------------------------------
try:
    from google.oauth2 import service_account
    import requests
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Install with: pip3 install google-auth requests")
    sys.exit(1)

# -----------------------------------------------
# Step 2: Authenticate with service account
# -----------------------------------------------
SCOPES = [
    "https://www.googleapis.com/auth/webmasters.readonly",
    "https://www.googleapis.com/auth/indexing",
]

print("Authenticating with Google Search Console API...")

try:
    credentials = service_account.Credentials.from_service_account_file(
        CREDENTIALS_PATH, scopes=SCOPES
    )
except Exception as e:
    print(f"Failed to load credentials: {e}")
    sys.exit(1)

# Get access token
from google.auth.transport.requests import Request
credentials.refresh(Request())
access_token = credentials.token

if not access_token:
    print("Failed to obtain access token.")
    sys.exit(1)

print("Authentication successful.")

headers = {
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json",
}

# -----------------------------------------------
# Step 3: Load local page URLs
# -----------------------------------------------
print(f"Scanning local pages in {PAGES_DIR}...")

local_pages = {}
for filepath in sorted(glob.glob(os.path.join(PAGES_DIR, "*.json"))):
    try:
        with open(filepath) as f:
            data = json.load(f)
        url = data.get("url", "")
        keyword = data.get("keyword", "")
        if url and url.startswith("/"):
            full_url = f"https://mysupermarketcompare.com{url}"
            local_pages[full_url] = {
                "path": url,
                "keyword": keyword,
                "filename": os.path.basename(filepath),
            }
    except Exception:
        continue

print(f"Found {len(local_pages)} local pages")

# -----------------------------------------------
# Step 4: Query Search Analytics API
# -----------------------------------------------
end_date = datetime.now().strftime("%Y-%m-%d")
start_date = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")

print(f"Querying Search Analytics ({start_date} to {end_date})...")

search_analytics_url = (
    f"https://www.googleapis.com/webmasters/v3/sites/"
    f"{requests.utils.quote(SITE_URL, safe='')}/searchAnalytics/query"
)

request_body = {
    "startDate": start_date,
    "endDate": end_date,
    "dimensions": ["page"],
    "rowLimit": 5000,
}

# Performance data from Search Analytics
performance_data = {}

try:
    response = requests.post(
        search_analytics_url,
        headers=headers,
        json=request_body,
        timeout=30,
    )

    if response.status_code == 200:
        result = response.json()
        rows = result.get("rows", [])
        print(f"Search Analytics returned {len(rows)} page entries")

        for row in rows:
            page_url = row["keys"][0]
            performance_data[page_url] = {
                "clicks": row.get("clicks", 0),
                "impressions": row.get("impressions", 0),
                "ctr": round(row.get("ctr", 0), 4),
                "position": round(row.get("position", 0), 1),
            }
    elif response.status_code == 403:
        print("Access denied. Check that the service account has access to the GSC property.")
        print(f"Response: {response.text}")
    else:
        print(f"Search Analytics API error (HTTP {response.status_code}): {response.text}")

except requests.exceptions.RequestException as e:
    print(f"Search Analytics request failed: {e}")

# -----------------------------------------------
# Step 5: Query URL Inspection API for index status
# -----------------------------------------------
print("Checking index status via URL Inspection API...")

inspection_url = "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect"

index_data = {}
inspected = 0
inspection_errors = 0

for full_url, page_info in local_pages.items():
    try:
        inspect_body = {
            "inspectionUrl": full_url,
            "siteUrl": SITE_URL,
        }

        resp = requests.post(
            inspection_url,
            headers=headers,
            json=inspect_body,
            timeout=15,
        )

        if resp.status_code == 200:
            result = resp.json()
            inspection = result.get("inspectionResult", {})
            index_result = inspection.get("indexStatusResult", {})

            verdict = index_result.get("verdict", "VERDICT_UNSPECIFIED")
            coverage = index_result.get("coverageState", "")
            indexing_state = index_result.get("indexingState", "")

            # Map verdict to simple indexed/not_indexed
            if verdict == "PASS":
                index_status = "indexed"
            elif verdict == "NEUTRAL":
                index_status = "not_indexed"
            elif verdict == "FAIL":
                index_status = "not_indexed"
            else:
                index_status = "unknown"

            index_data[full_url] = {
                "verdict": verdict,
                "coverage": coverage,
                "indexing_state": indexing_state,
                "index_status": index_status,
            }
            inspected += 1

        elif resp.status_code == 429:
            print(f"  Rate limited at {inspected} inspections. Continuing with available data.")
            break
        elif resp.status_code == 403:
            print("  URL Inspection API access denied. Falling back to Search Analytics only.")
            inspection_errors += 1
            break
        else:
            print(f"  Inspection error for {page_info['path']}: HTTP {resp.status_code}")
            inspection_errors += 1

    except requests.exceptions.RequestException as e:
        print(f"  Inspection request failed for {page_info['path']}: {e}")
        inspection_errors += 1

print(f"Inspected {inspected} pages ({inspection_errors} errors)")

# -----------------------------------------------
# Step 6: Determine index status for each page
# -----------------------------------------------
# If URL Inspection API was unavailable, fall back
# to Search Analytics presence as a proxy for indexing.
use_inspection = inspected > 0

if not use_inspection:
    print("Falling back to Search Analytics presence for index status")

# -----------------------------------------------
# Step 7: Build combined report
# -----------------------------------------------
print("Building reports...")

os.makedirs(os.path.dirname(GSC_REPORT), exist_ok=True)

report_rows = []

for full_url, page_info in sorted(local_pages.items()):
    path = page_info["path"]

    # Performance data
    perf = performance_data.get(full_url, {})
    clicks = perf.get("clicks", 0)
    impressions = perf.get("impressions", 0)
    ctr = perf.get("ctr", 0)
    position = perf.get("position", 0)

    # Index status
    if use_inspection and full_url in index_data:
        indexed = index_data[full_url]["index_status"]
    elif full_url in performance_data:
        # If page has impressions in Search Analytics, it must be indexed
        indexed = "indexed" if impressions > 0 else "not_indexed"
    else:
        indexed = "not_indexed"

    report_rows.append({
        "url": full_url,
        "path": path,
        "indexed": indexed,
        "impressions": impressions,
        "clicks": clicks,
        "ctr": ctr,
        "position": position,
    })

# -----------------------------------------------
# Step 8: Write GSC report (full performance data)
# -----------------------------------------------
with open(GSC_REPORT, "w", newline="") as f:
    writer = csv.writer(f, lineterminator='\n')
    writer.writerow(["url", "indexed", "impressions", "clicks", "ctr", "position"])
    for row in report_rows:
        writer.writerow([
            row["url"],
            row["indexed"],
            row["impressions"],
            row["clicks"],
            row["ctr"],
            row["position"],
        ])

print(f"GSC report written to: {GSC_REPORT}")

# -----------------------------------------------
# Step 9: Write index-report.csv (compatible with
# crawl-budget-controller.sh)
# -----------------------------------------------
with open(INDEX_REPORT, "w", newline="") as f:
    writer = csv.writer(f, lineterminator='\n')
    writer.writerow(["url", "http_status", "index_status"])
    for row in report_rows:
        writer.writerow([
            row["url"],
            200,
            row["indexed"],
        ])

print(f"Index report written to: {INDEX_REPORT}")

# -----------------------------------------------
# Step 10: Print summary
# -----------------------------------------------
total = len(report_rows)
count_indexed = sum(1 for r in report_rows if r["indexed"] == "indexed")
count_not_indexed = sum(1 for r in report_rows if r["indexed"] == "not_indexed")
count_with_impressions = sum(1 for r in report_rows if r["impressions"] > 0)
count_with_clicks = sum(1 for r in report_rows if r["clicks"] > 0)
total_impressions = sum(r["impressions"] for r in report_rows)
total_clicks = sum(r["clicks"] for r in report_rows)
avg_ctr = sum(r["ctr"] for r in report_rows) / total if total > 0 else 0
positions = [r["position"] for r in report_rows if r["position"] > 0]
avg_position = sum(positions) / len(positions) if positions else 0

print(f"\n{'='*45}")
print(f"Google Search Console Report")
print(f"{'='*45}")
print(f"Date range:          {start_date} to {end_date}")
print(f"Total pages checked: {total}")
print(f"Pages indexed:       {count_indexed}")
print(f"Pages not indexed:   {count_not_indexed}")
print(f"Pages w/ impressions:{count_with_impressions}")
print(f"Pages w/ clicks:     {count_with_clicks}")
print(f"Total impressions:   {total_impressions}")
print(f"Total clicks:        {total_clicks}")
print(f"Average CTR:         {avg_ctr:.2%}")
print(f"Average position:    {avg_position:.1f}")
print(f"{'='*45}")

PYTHON_SCRIPT

echo "======================================="
