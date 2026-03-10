#!/usr/bin/env bash
# =============================================================================
# REAL-TIME ENFORCER - Used by AI agent hooks
# Called per-file by: pre-write, post-write, pre-commit hooks
# Thread-safe: No shared state, no temp files
# =============================================================================
set -euo pipefail

# Color variables - MUST be defined first
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

critical=0

[[ $# -eq 0 ]] && { echo "Usage: bash-enforcer.sh <file.sh>"; exit 1; }
[[ ! -e "$1" ]] && { echo "Error: File not found: $1"; exit 1; }

echo "🔍 Checking Bash file: $1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check set -e (required)
if ! grep -q "^[[:space:]]*set -e" "$1"; then
    echo -e "${RED}❌ FAIL${NC}: Missing 'set -e'"
    ((critical++)) || true
fi

# Check set -u (required)
if ! grep -qE "^[[:space:]]*set -.*u" "$1"; then
    echo -e "${RED}❌ FAIL${NC}: Missing 'set -u'"
    ((critical++)) || true
fi

# Check set -o pipefail (required)
if ! grep -qE "^[[:space:]]*set -.*o pipefail" "$1"; then
    echo -e "${RED}❌ FAIL${NC}: Missing 'set -o pipefail'"
    ((critical++)) || true
fi

# Check for TODO/FIXME (common placeholder)
if grep -qiE "(TODO|FIXME|HACK|XXX|TEMP|WIP|PLACEHOLDER):" "$1"; then
    TODO_LINES=$(grep -niE "(TODO|FIXME|HACK|XXX|TEMP|WIP|PLACEHOLDER):" "$1" | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
    echo -e "${RED}❌ FAIL${NC}: Placeholder comments found"
    echo "   Lines: $TODO_LINES"
    ((critical++)) || true
fi

# Check for unsafe rm variants
# Matches: rm -rf, rm -r -f, rm -f -r, rm -R, rm --recursive, rm -rf /, rm -rf .
if grep -qE 'rm\s+-[rRfF]+' "$1"; then
    UNSAFE_RM_LINES=$(grep -nE 'rm\s+-[rRfF]+' "$1" | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
    echo -e "${RED}❌ FAIL${NC}: Unsafe rm command found"
    echo "   Lines: $UNSAFE_RM_LINES"
    ((critical++)) || true
fi

# Check for rm -rf / (catastrophic) - match rm -rf followed by / (root) or . (current dir)
if grep -qE 'rm\s+-[rRfF]+[[:space:]]+(/|\.)([[:space:]]|$)' "$1"; then
    DANGEROUS_RM=$(grep -nE 'rm\s+-[rRfF]+[[:space:]]+(/|\.)' "$1" | grep -v '^.*#' | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
    if [[ -n "$DANGEROUS_RM" ]]; then
        echo -e "${RED}❌ FAIL${NC}: Potentially catastrophic rm command"
        echo "   Lines: $DANGEROUS_RM"
        ((critical++)) || true
    fi
fi

# Check for backticks (deprecated - should use $())
if grep -qE '`.*`' "$1"; then
    BACKTICK_LINES=$(grep -nE '`' "$1" | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
    echo -e "${RED}❌ FAIL${NC}: Backticks found (use \$(...) instead)"
    echo "   Lines: $BACKTICK_LINES"
    ((critical++)) || true
fi

# Check for eval (security risk)
if grep -qE '\beval\s+' "$1"; then
    EVAL_LINES=$(grep -nE '\beval\s+' "$1" | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
    echo -e "${RED}❌ FAIL${NC}: eval() usage detected (security risk)"
    echo "   Lines: $EVAL_LINES"
    ((critical++)) || true
fi

# Check for debug mode (set -x)
if grep -qE '^[[:space:]]*set -x' "$1"; then
    DEBUG_LINES=$(grep -nE '^[[:space:]]*set -x' "$1" | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
    echo -e "${RED}❌ FAIL${NC}: Debug mode (set -x) should not be in production"
    echo "   Lines: $DEBUG_LINES"
    ((critical++)) || true
fi

# Check for hardcoded secrets (basic patterns)
if grep -qE "(password|api_key|apikey|secret|token)\s*=\s*['\"]?[a-zA-Z0-9_-]{8,}" "$1"; then
    SECRET_LINES=$(grep -nE "(password|api_key|apikey|secret|token)\s*=\s*['\"]?[a-zA-Z0-9_-]{8,}" "$1" | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
    echo -e "${RED}❌ FAIL${NC}: Potential hardcoded secret detected"
    echo "   Lines: $SECRET_LINES"
    ((critical++)) || true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ $critical -eq 0 ]] && echo -e "${GREEN}✅ Check passed!${NC}" || echo -e "${RED}❌ Check FAILED${NC}"
[[ $critical -eq 0 ]] && exit 0 || exit 1
