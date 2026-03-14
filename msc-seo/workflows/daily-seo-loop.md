# Daily SEO Loop

This workflow runs every day via cron and manages the autonomous SEO growth of MySupermarketCompare.

The workflow must execute in the following order.

---

STEP 1 — Keyword opportunity scan

Scan:

data/target-keywords.csv

Identify keywords that do not yet have pages created in:

site/src/data/pages/

---

STEP 2 — Competitor gap analysis

Review competitor keywords defined in:

knowledge/competitor-list.md

Identify additional keywords missing from the MySupermarketCompare site.

Append valid opportunities to:

data/target-keywords.csv

---

STEP 3 — Generate new pages

For up to 5 opportunities per run:

Execute the workflow:

workflows/page-generator.md

This will create JSON page definitions inside:

site/src/data/pages/

---

STEP 4 — Validate pages

Ensure generated JSON files:

• are valid JSON  
• follow page family structures  
• comply with Seopa rules

Reject any pages failing validation.

---

STEP 5 — Publish pages

Execute:

workflows/git-publish.sh

This will:

• commit new page files  
• push them to GitHub  
• trigger Vercel deployment

---

STEP 6 — Generate daily report

Write a report to:

reports/daily-seo-report.md

Include:

• pages generated
• pages skipped
• new keyword opportunities
• SEO recommendations

---

STEP 7 — End workflow

The system waits for the next scheduled cron execution.
