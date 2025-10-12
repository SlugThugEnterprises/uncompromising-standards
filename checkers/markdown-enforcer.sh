#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

critical=0
warnings=0

[[ $# -eq 0 ]] && { echo "Usage: markdown-enforcer.sh <file.md>"; exit 1; }
[[ ! -f "$1" ]] && { echo "Error: File not found: $1"; exit 1; }

echo "🔍 Checking Markdown file: $1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for TODO/FIXME
grep -iq "TODO\|FIXME\|HACK\|XXX" "$1" && { echo -e "${RED}🚨 CRITICAL${NC}: Unfinished placeholders found"; ((critical++)); }

# Check for broken links
grep -oP '\[.*?\]\(.*?\)' "$1" | while read link; do
    url=$(echo "$link" | sed 's/.*(\(.*\)).*/\1/')
    [[ "$url" =~ ^http ]] && echo -e "${YELLOW}⚠️  WARNING${NC}: External link: $url"; ((warnings++))
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ $critical -eq 0 ]] && echo -e "${GREEN}✅ Check passed!${NC}" || echo -e "${RED}❌ Check FAILED${NC}"
exit $critical
