# Page Generator Workflow

This workflow converts SEO opportunities into structured page definitions for MySupermarketCompare.com.

The output must be compatible with the Next.js dynamic routing system used by the live site.

The live site repository is available at:

site/

Generated SEO pages must be saved into:

site/src/data/pages/

---

STEP 1 — SELECT OPPORTUNITY

Take one keyword opportunity from:

data/target-keywords.csv

Example:

car insurance london

Do not generate pages outside approved target opportunities unless explicitly instructed.

---

STEP 2 — VALIDATE STRUCTURE

Ensure the page matches an approved page family defined in:

knowledge/page-families.md

Example:

/car-insurance/{city}

If the page does not match an approved structure, do not generate it.

---

STEP 3 — CHECK FOR EXISTING PAGE

Before generating the page, check whether the target JSON file already exists in:

site/src/data/pages/

Example:

site/src/data/pages/car-insurance-london.json

If the file already exists, do not overwrite it unless explicitly instructed.

---

STEP 4 — GENERATE PAGE METADATA

Create structured page data including:

- keyword
- url
- pageFamily
- title
- description
- h1

---

STEP 5 — GENERATE PAGE CONTENT

Generate useful structured content including:

- introduction
- explanation of the insurance situation
- comparison guidance
- CTA to compare quotes
- FAQ section
- internal links to related pages

All content must comply with:

knowledge/seopa-rules.md

---

STEP 6 — OUTPUT VALID JSON

Output a valid JSON object containing:

- keyword
- url
- pageFamily
- title
- description
- h1
- sections
- faq
- compliance
- internalLinks

The JSON must be valid and production-safe.

---

STEP 7 — SAVE TO LIVE SITE REPO

Save the generated page JSON into:

site/src/data/pages/

Filename format:

car-insurance-{slug}.json

Example:

site/src/data/pages/car-insurance-manchester.json

---

STEP 8 — REPORT RESULT

After generating the page, report:

- keyword used
- file created
- URL created
- whether the page was new or skipped
