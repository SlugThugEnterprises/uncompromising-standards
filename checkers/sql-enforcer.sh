#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

critical=0

[[ $# -eq 0 ]] && { echo "Usage: sql-enforcer.sh <file.sql>"; exit 1; }
[[ ! -f "$1" ]] && { echo "Error: File not found: $1"; exit 1; }

echo "🔍 Checking SQL file: $1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

grep -iq "SELECT \*" "$1" && { echo -e "${RED}🚨 CRITICAL${NC}: SELECT * found - specify columns"; ((critical++)); }
grep -iq "DROP TABLE.*IF NOT EXISTS" "$1" || grep -iq "DROP DATABASE" "$1" && { echo -e "${RED}🚨 CRITICAL${NC}: Unsafe DROP found"; ((critical++)); }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ $critical -eq 0 ]] && echo -e "${GREEN}✅ Check passed!${NC}" || echo -e "${RED}❌ Check FAILED${NC}"
exit $critical
