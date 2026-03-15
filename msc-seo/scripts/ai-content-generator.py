#!/usr/bin/env python3

"""
AI Content Generator for MSC SEO Pipeline

Calls the Claude API to generate keyword-specific section
content and FAQ items for insurance comparison pages.

Usage:
    python3 ai-content-generator.py <keyword> <vertical_slug>

Requires:
    CLAUDE_API_KEY environment variable

Output:
    JSON to stdout with structure:
    {
      "intro": "...",
      "sections": [{"id": "...", "heading": "...", "content": "...", "bullets": [...]}],
      "faq": [{"question": "...", "answer": "..."}]
    }

Exit codes:
    0 = success
    1 = error (fallback to template)
"""

import json
import os
import sys
import urllib.error
import urllib.request


API_URL = "https://api.anthropic.com/v1/messages"
API_VERSION = "2023-06-01"
DEFAULT_MODEL = "claude-sonnet-4-20250514"
MAX_TOKENS = 4096
TIMEOUT_SECONDS = 60


def build_prompt(keyword, vertical_slug):
    """Build the Claude prompt for content generation."""

    kw_title = " ".join(
        w if (w.isdigit() or (w[0].isdigit() if w else False)) else w.capitalize()
        for w in keyword.split()
    )
    vertical_display = vertical_slug.replace("-", " ").title()

    return f"""You are writing SEO content for a UK insurance comparison website called MySupermarketCompare. Generate content for a page about "{keyword}" in the "{vertical_display}" vertical.

The page helps users compare {keyword} quotes from multiple UK providers via Quotezone.

Generate content as a JSON object with this exact structure:

{{
  "intro": "Introduction paragraph, 60-80 words, naturally incorporating '{keyword}'",
  "sections": [
    {{
      "id": "how-it-works",
      "heading": "How {kw_title} Works",
      "content": "150-200 words explaining how this type of insurance or cover works, specific to {keyword}"
    }},
    {{
      "id": "cost-factors",
      "heading": "What Affects The Cost Of {kw_title}",
      "content": "One introductory sentence about factors affecting {keyword} premiums",
      "bullets": ["factor 1 - brief explanation", "factor 2 - brief explanation"]
    }},
    {{
      "id": "who-is-it-for",
      "heading": "Who Is {kw_title} Suitable For",
      "content": "100-150 words about who would benefit from comparing {keyword} quotes"
    }},
    {{
      "id": "tips-to-reduce-cost",
      "heading": "Tips To Help Reduce Your {kw_title} Premium",
      "content": "One introductory sentence about managing {keyword} costs",
      "bullets": ["tip 1 - brief explanation", "tip 2 - brief explanation"]
    }},
    {{
      "id": "keyword-specific-section",
      "heading": "A heading specific to {keyword} that adds unique value",
      "content": "100-150 words of content specific to this keyword that would not appear on other pages"
    }}
  ],
  "faq": [
    {{"question": "Question about {keyword}?", "answer": "40-80 word answer"}},
    {{"question": "Second question?", "answer": "40-80 word answer"}},
    {{"question": "Third question?", "answer": "40-80 word answer"}},
    {{"question": "Fourth question?", "answer": "40-80 word answer"}},
    {{"question": "Fifth question?", "answer": "40-80 word answer"}}
  ]
}}

RULES:
- Write factual UK insurance information only
- Do NOT mention specific insurance companies, brands, or providers by name
- Do NOT quote specific prices, premiums, or savings figures
- Maintain a neutral, informative tone throughout
- Naturally incorporate the keyword "{keyword}" in the content
- All content must be specific to {keyword}, not generic insurance advice
- Use British English spelling (e.g. "colour", "organisation", "optimise")
- Do NOT use em dashes or en dashes. Use hyphens (-) or commas instead
- The cost-factors section must have 5-7 bullet points
- The tips-to-reduce-cost section must have 5-7 bullet points
- The keyword-specific section should cover something unique to {keyword} that differentiates it from generic {vertical_display} pages
- Each FAQ answer should be 40-80 words
- Generate exactly 5 sections and exactly 5 FAQ items
- Output ONLY valid JSON with no markdown formatting, no code blocks, no extra text"""


def call_claude_api(api_key, prompt, model):
    """Call the Claude API and return the response text."""

    request_body = json.dumps({
        "model": model,
        "max_tokens": MAX_TOKENS,
        "messages": [{"role": "user", "content": prompt}],
    }).encode("utf-8")

    headers = {
        "x-api-key": api_key,
        "anthropic-version": API_VERSION,
        "content-type": "application/json",
    }

    req = urllib.request.Request(API_URL, data=request_body, headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
            response_data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace") if e.fp else ""
        print(f"Claude API HTTP error {e.code}: {body}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Claude API connection error: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except TimeoutError:
        print("Claude API request timed out", file=sys.stderr)
        sys.exit(1)

    # Extract text from response
    content_blocks = response_data.get("content", [])
    for block in content_blocks:
        if block.get("type") == "text":
            return block["text"]

    print("No text content in Claude API response", file=sys.stderr)
    sys.exit(1)


def parse_ai_response(text):
    """Parse the AI response text into structured JSON."""

    # Strip markdown code fences if present
    cleaned = text.strip()
    if cleaned.startswith("```"):
        # Remove opening fence (with optional language tag)
        first_newline = cleaned.index("\n")
        cleaned = cleaned[first_newline + 1:]
    if cleaned.endswith("```"):
        cleaned = cleaned[:-3]
    cleaned = cleaned.strip()

    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError as e:
        print(f"Failed to parse AI response as JSON: {e}", file=sys.stderr)
        sys.exit(1)

    # Validate required fields
    if not isinstance(data.get("intro"), str) or not data["intro"]:
        print("AI response missing 'intro' field", file=sys.stderr)
        sys.exit(1)

    sections = data.get("sections", [])
    if not isinstance(sections, list) or len(sections) < 4:
        print(f"AI response has {len(sections)} sections, need at least 4", file=sys.stderr)
        sys.exit(1)

    faqs = data.get("faq", [])
    if not isinstance(faqs, list) or len(faqs) < 5:
        print(f"AI response has {len(faqs)} FAQs, need at least 5", file=sys.stderr)
        sys.exit(1)

    # Validate each section has required fields
    for i, sec in enumerate(sections):
        if not sec.get("id") or not sec.get("heading") or not sec.get("content"):
            print(f"AI section {i} missing required fields", file=sys.stderr)
            sys.exit(1)

    # Validate each FAQ has required fields
    for i, faq in enumerate(faqs):
        if not faq.get("question") or not faq.get("answer"):
            print(f"AI FAQ {i} missing required fields", file=sys.stderr)
            sys.exit(1)

    return data


def main():
    if len(sys.argv) != 3:
        print("Usage: ai-content-generator.py <keyword> <vertical_slug>", file=sys.stderr)
        sys.exit(1)

    keyword = sys.argv[1]
    vertical_slug = sys.argv[2]

    api_key = os.environ.get("CLAUDE_API_KEY")
    if not api_key:
        print("CLAUDE_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    model = os.getenv("CLAUDE_MODEL", DEFAULT_MODEL)
    # Reject alias model names (e.g. "latest") that cause 404 on the API
    if "latest" in model:
        print(f"CLAUDE_MODEL '{model}' is an alias, using {DEFAULT_MODEL}", file=sys.stderr)
        model = DEFAULT_MODEL
    prompt = build_prompt(keyword, vertical_slug)
    response_text = call_claude_api(api_key, prompt, model)
    result = parse_ai_response(response_text)

    # Output clean JSON to stdout
    print(json.dumps(result))


if __name__ == "__main__":
    main()
