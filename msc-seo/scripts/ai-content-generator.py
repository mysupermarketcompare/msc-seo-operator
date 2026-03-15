#!/usr/bin/env python3

"""
AI Content Generator for MSC SEO Pipeline

Calls the Claude API to generate keyword-specific section
content and FAQ items for insurance comparison pages.
"""

import json
import os
import sys
import urllib.error
import urllib.request
import subprocess

API_URL = "https://api.anthropic.com/v1/messages"
API_VERSION = "2023-06-01"
DEFAULT_MODEL = "claude-sonnet-4-20250514"
MAX_TOKENS = 4096
TIMEOUT_SECONDS = 60


def get_serp_topics(keyword):
    """Fetch SERP topics from the topic extractor"""

    try:
        result = subprocess.run(
            ["python3", "scripts/serp-topic-extractor.py", keyword],
            capture_output=True,
            text=True,
            timeout=20
        )

        data = json.loads(result.stdout)

        return data.get("topics", [])

    except Exception:
        return []


def build_prompt(keyword, vertical_slug):
    """Build the Claude prompt for content generation."""

    kw_title = " ".join(
        w if (w.isdigit() or (w[0].isdigit() if w else False)) else w.capitalize()
        for w in keyword.split()
    )

    vertical_display = vertical_slug.replace("-", " ").title()

    serp_topics = get_serp_topics(keyword)

    serp_context = ""

    if serp_topics:
        serp_context = f"""
Google currently ranks pages covering these related topics:

{", ".join(serp_topics)}

Your content should naturally cover some of these ideas where relevant.
"""

    return f"""You are writing SEO content for a UK insurance comparison website called MySupermarketCompare.

Keyword: "{keyword}"
Vertical: "{vertical_display}"

{serp_context}

The page helps users compare {keyword} quotes from multiple UK providers via Quotezone.

Generate content as a JSON object with this exact structure:

{{
  "intro": "Introduction paragraph, 60-80 words, naturally incorporating '{keyword}'",
  "sections": [
    {{
      "id": "how-it-works",
      "heading": "How {kw_title} Works",
      "content": "150-200 words explaining how this type of insurance works"
    }},
    {{
      "id": "cost-factors",
      "heading": "What Affects The Cost Of {kw_title}",
      "content": "One sentence intro",
      "bullets": ["factor 1", "factor 2"]
    }},
    {{
      "id": "who-is-it-for",
      "heading": "Who Is {kw_title} Suitable For",
      "content": "100-150 words"
    }},
    {{
      "id": "tips-to-reduce-cost",
      "heading": "Tips To Help Reduce Your {kw_title} Premium",
      "content": "One sentence intro",
      "bullets": ["tip 1", "tip 2"]
    }},
    {{
      "id": "keyword-specific-section",
      "heading": "A heading specific to {keyword}",
      "content": "100-150 words unique to this keyword"
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

Rules:

- Write factual UK insurance information only
- Do NOT mention insurance companies
- Do NOT quote prices
- Use British English
- Write neutrally and informatively
- Include the keyword naturally
- Generate exactly 5 sections
- Generate exactly 5 FAQ items

Output ONLY valid JSON.
"""


def call_claude_api(api_key, prompt, model):

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

    content_blocks = response_data.get("content", [])

    for block in content_blocks:

        if block.get("type") == "text":

            return block["text"]

    print("No text content in Claude API response", file=sys.stderr)

    sys.exit(1)


def parse_ai_response(text):

    cleaned = text.strip()

    if cleaned.startswith("```"):

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

    if "latest" in model:

        print(f"CLAUDE_MODEL '{model}' is an alias, using {DEFAULT_MODEL}", file=sys.stderr)

        model = DEFAULT_MODEL

    prompt = build_prompt(keyword, vertical_slug)

    response_text = call_claude_api(api_key, prompt, model)

    result = parse_ai_response(response_text)

    print(json.dumps(result))


if __name__ == "__main__":

    main()
