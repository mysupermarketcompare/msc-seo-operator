#!/bin/bash

echo "======================================="
echo "Starting MySupermarketCompare SEO operator"
echo "Time: $(date)"
echo "======================================="

WORKSPACE=~/.openclaw/workspace/msc-seo
SITE=~/MSCINSURANCE-1

echo "Running keyword opportunity scan..."

KEYWORDS="$WORKSPACE/data/target-keywords.csv"
PAGES="$SITE/src/data/pages"

mkdir -p "$PAGES"

NEW_PAGES=0

tail -n +2 "$KEYWORDS" | while IFS=',' read -r vertical keyword url; do

slug=$(echo "$keyword" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
file="$PAGES/$slug.json"

if [ ! -f "$file" ]; then

echo "Generating page: $keyword"

cat > "$file" <<EOF
{
  "keyword": "$keyword",
  "url": "$url",
  "title": "$keyword | Compare Quotes | MySupermarketCompare",
  "description": "Compare $keyword and find the right cover using our insurance comparison service.",
  "h1": "$keyword",
  "sections": [
    {
      "heading": "Compare $keyword",
      "content": "Use MySupermarketCompare to compare insurance quotes and explore your cover options."
    }
  ],
  "faq": [
    {
      "question": "How do I compare $keyword?",
      "answer": "You can compare quotes through our comparison partner Quotezone."
    }
  ]
}
EOF

NEW_PAGES=$((NEW_PAGES+1))

fi

done

echo "Checking repo status..."

cd "$SITE"

git add .

if git diff --cached --quiet; then
echo "No new SEO pages found."
else
echo "Publishing new pages..."
git commit -m "SEO operator generated pages"
git push
fi

echo "---------------------------------------"
echo "SEO operator run complete"
echo "======================================="