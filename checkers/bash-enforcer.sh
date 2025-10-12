#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

critical=0

[[ $# -eq 0 ]] && { echo "Usage: bash-enforcer.sh <file.sh>"; exit 1; }
[[ ! -f "$1" ]] && { echo "Error: File not found: $1"; exit 1; }

echo "🔍 Checking Bash file: $1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check set -e
grep -q "set -e" "$1" || { echo -e "${RED}🚨 CRITICAL${NC}: Missing 'set -e'"; ((critical++)); }

# Check unquoted variables
if grep -P '\$\{?[a-zA-Z_][a-zA-Z0-9_]*\}?' "$1" | grep -v '"' | grep -qv "#"; then
    echo -e "${RED}🚨 CRITICAL${NC}: Unquoted variables found"
    ((critical++))
fi

# Check rm -rf without safeguards
grep -q "rm -rf" "$1" && { echo -e "${RED}🚨 CRITICAL${NC}: Unsafe rm -rf found"; ((critical++)); }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ $critical -eq 0 ]] && echo -e "${GREEN}✅ Check passed!${NC}" || echo -e "${RED}❌ Check FAILED${NC}"
exit $critical
