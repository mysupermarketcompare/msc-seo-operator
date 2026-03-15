#!/usr/bin/env python3
"""SERP Topic Extractor — extracts h1/h2 headings from pages ranking
for a keyword. Tries Google SERP first, falls back to UK competitor URLs.
Usage: python3 serp-topic-extractor.py "backpackers travel insurance"
Output: JSON to stdout."""

import json, re, sys, time
from urllib.parse import urlparse
import requests
from bs4 import BeautifulSoup

TIMEOUT, REQUEST_DELAY, MAX_RESULTS, MIN_HEADING_WORDS = 5, 1.0, 5, 3
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                  "AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36",
    "Accept-Language": "en-GB,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml",
}

SKIP_DOMAINS = {"youtube.com", "google.com", "google.co.uk", "facebook.com",
    "twitter.com", "instagram.com", "reddit.com", "tiktok.com"}
NAV_PATTERNS = ["cookie", "privacy", "terms", "menu", "navigation", "footer",
    "sidebar", "subscribe", "sign up", "log in", "share this",
    "related articles", "leave a comment", "table of contents",
    "skip to content", "banking and bills", "posting", "identity",
    "pardon our interruption", "myaviva", "your account",
    "get in touch", "about us", "our partners", "customer service"]
COMPETITOR_SITES = [
    "https://www.money.co.uk/{vertical}/{slug}",
    "https://www.money.co.uk/{vertical}",
    "https://www.which.co.uk/money/insurance/{vertical}",
    "https://www.postoffice.co.uk/{vertical}/{slug}",
    "https://www.gocompare.com/{vertical}/{slug}",
    "https://www.aviva.co.uk/{vertical}/{slug}",
]
VERTICAL_MAP = {
    "car insurance": "car-insurance", "home insurance": "home-insurance",
    "travel insurance": "travel-insurance", "pet insurance": "pet-insurance",
    "van insurance": "van-insurance", "motorbike insurance": "motorbike-insurance",
    "motorcycle insurance": "motorbike-insurance", "bicycle insurance": "bicycle-insurance",
    "cycle insurance": "bicycle-insurance", "breakdown cover": "breakdown-cover",
    "breakdown insurance": "breakdown-cover",
}


def search_google(keyword):
    """Fetch Google SERP and return organic result URLs."""
    try:
        resp = requests.get(
            "https://www.google.com/search",
            params={"q": keyword, "hl": "en", "gl": "uk", "num": "10"},
            headers=HEADERS, timeout=TIMEOUT,
        )
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f"Google search failed: {e}", file=sys.stderr)
        return []

    if "enablejs" in resp.text[:2000]:
        print("Google returned JS-required page", file=sys.stderr)
        return []

    soup = BeautifulSoup(resp.text, "html.parser")
    urls = []
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if href.startswith("/url?q="):
            href = href.split("/url?q=")[1].split("&")[0]
        elif not href.startswith("http"):
            continue
        parsed = urlparse(href)
        domain = parsed.netloc.lower().lstrip("www.")
        if domain in SKIP_DOMAINS or "google" in domain:
            continue
        if any(urlparse(u).netloc == parsed.netloc for u in urls):
            continue
        urls.append(href)
        if len(urls) >= MAX_RESULTS:
            break
    return urls


def detect_vertical(keyword):
    """Infer the insurance vertical from the keyword."""
    kw = keyword.lower()
    for fragment, vertical in sorted(VERTICAL_MAP.items(), key=lambda x: -len(x[0])):
        if fragment in kw:
            return vertical
    return None


def build_competitor_urls(keyword):
    """Construct likely competitor URLs from the keyword."""
    vertical = detect_vertical(keyword)
    if not vertical:
        return []
    slug = keyword.lower()
    for fragment in VERTICAL_MAP:
        if fragment in slug:
            slug = slug.replace(fragment, "").strip()
            break
    slug = re.sub(r"[^a-z0-9\s-]", "", slug)
    slug = re.sub(r"\s+", "-", slug).strip("-")
    if not slug:
        slug = re.sub(r"\s+", "-", re.sub(r"[^a-z0-9\s-]", "", keyword.lower())).strip("-")
    return [t.format(vertical=vertical, slug=slug) for t in COMPETITOR_SITES]


def fetch_headings(url):
    """Fetch a page and extract h1/h2 heading text."""
    try:
        resp = requests.get(url, headers=HEADERS, timeout=TIMEOUT, allow_redirects=True)
        if resp.status_code != 200:
            return []
    except requests.RequestException:
        return []
    if "html" not in resp.headers.get("Content-Type", "").lower():
        return []
    soup = BeautifulSoup(resp.text, "html.parser")
    return [t.get_text(separator=" ", strip=True)
            for t in soup.find_all(["h1", "h2"])
            if t.get_text(strip=True)]


def clean_heading(text):
    """Normalise a heading: lowercase, strip punctuation, collapse spaces."""
    text = text.lower().strip()
    text = re.sub(r"^[\d]+[.)]\s*", "", text)
    text = re.sub(r"[^\w\s'-]", "", text)
    return re.sub(r"\s+", " ", text).strip()


def is_valid_heading(text, keyword):
    """Check heading meets minimum quality bar and topical relevance."""
    words = text.split()
    if len(words) < MIN_HEADING_WORDS or len(words) > 20:
        return False
    if any(p in text for p in NAV_PATTERNS):
        return False
    stop = {"a", "an", "the", "and", "or", "for", "to", "of", "in", "is",
            "insurance", "cover", "policy", "policies", "compare", "quotes"}
    kw_words = set(keyword.lower().split()) - stop
    if not kw_words:
        kw_words = set(keyword.lower().split())
    return bool(kw_words & set(words))


def main():
    if len(sys.argv) != 2 or not sys.argv[1].strip():
        print("Usage: serp-topic-extractor.py <keyword>", file=sys.stderr)
        sys.exit(1)

    keyword = sys.argv[1].strip()
    print(f"Searching Google for: {keyword}", file=sys.stderr)
    urls = search_google(keyword)

    if not urls:
        print("Google blocked, using competitor URL fallback", file=sys.stderr)
        urls = build_competitor_urls(keyword)

    if not urls:
        print("No URLs to fetch", file=sys.stderr)
        print(json.dumps({"keyword": keyword, "topics": []}))
        sys.exit(0)

    print(f"Fetching {len(urls)} URLs", file=sys.stderr)
    all_headings = []
    for i, url in enumerate(urls):
        print(f"  [{i + 1}/{len(urls)}] {url[:80]}", file=sys.stderr)
        all_headings.extend(fetch_headings(url))
        if i < len(urls) - 1:
            time.sleep(REQUEST_DELAY)

    seen = set()
    topics = []
    for h in all_headings:
        c = clean_heading(h)
        if c not in seen and is_valid_heading(c, keyword):
            seen.add(c)
            topics.append(c)
    topics.sort()

    print(json.dumps({"keyword": keyword, "topics": topics}, indent=2))


if __name__ == "__main__":
    main()
