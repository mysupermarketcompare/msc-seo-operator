#!/bin/bash
set -e

cd ~/MSCINSURANCE-1

echo "Checking repo status..."
git status --short

echo "Detecting new SEO page files..."
NEW_FILES=$(git ls-files --others --exclude-standard src/data/pages/*.json)

if [ -z "$NEW_FILES" ]; then
  echo "No new SEO pages found."
  exit 0
fi

echo "New pages detected:"
echo "$NEW_FILES"

echo "Validating JSON files..."
for file in $NEW_FILES; do
  python3 -m json.tool "$file" > /dev/null
done

echo "Staging new pages..."
git add $NEW_FILES

echo "Checking staged diff..."
git diff --cached --name-only

echo "Creating commit..."
git commit -m "SEO: add new programmatic SEO pages"

echo "Pushing to GitHub..."
git push origin main

echo "Deployment triggered via Vercel."