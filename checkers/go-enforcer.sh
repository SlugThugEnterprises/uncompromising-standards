#!/usr/bin/env bash
set -uo pipefail

# Go Code Enforcer - Uncompromising Standards
# "Code so good you could trust it with your friend's mom's life"

EXIT_CODE=0
WARNINGS=0
ERRORS=0
CRITICAL=0

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ $# -eq 0 ]; then
    echo "Usage: $0 <go-file.go>"
    exit 1
fi

GO_FILE="$1"

if [ ! -f "$GO_FILE" ]; then
    echo "Error: File not found: $GO_FILE"
    exit 1
fi

# Critical patterns
declare -A CRITICAL_PATTERNS=(
    ["panic"]='panic\('
    ["todo"]='(TODO|FIXME|HACK|XXX|TEMP|WIP|PLACEHOLDER)'
    ["nil_deref"]='\.nil\b'
    ["err_ignore"]='_\s*=\s*.*\(.*\)'
)

# Error patterns
declare -A ERROR_PATTERNS=(
    ["fmt_print"]='fmt\.Print(ln|f)?\('
)

check_pattern() {
    local pattern="$1"
    local severity="$2"
    local description="$3"
    local file="$4"

    if grep -Pq "$pattern" "$file" 2>/dev/null; then
        local line_numbers=$(grep -Pn "$pattern" "$file" 2>/dev/null | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')

        case "$severity" in
            critical)
                echo -e "${RED}🚨 CRITICAL${NC}: $description"
                echo "   File: $file"
                echo "   Lines: $line_numbers"
                ((CRITICAL++))
                EXIT_CODE=1
                ;;
            error)
                echo -e "${RED}❌ ERROR${NC}: $description"
                echo "   File: $file"
                echo "   Lines: $line_numbers"
                ((ERRORS++))
                ;;
            warning)
                echo -e "${YELLOW}⚠️  WARNING${NC}: $description"
                echo "   File: $file"
                echo "   Lines: $line_numbers"
                ((WARNINGS++))
                ;;
        esac
    fi
}

echo "🔍 Checking Go file: $GO_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check file length
LINE_COUNT=$(wc -l < "$GO_FILE")
if [ $LINE_COUNT -gt 200 ]; then
    echo -e "${RED}🚨 CRITICAL${NC}: File exceeds 200 lines"
    echo "   File: $GO_FILE"
    echo "   Lines: $LINE_COUNT (limit: 200)"
    ((CRITICAL++))
    EXIT_CODE=1
fi

# Check patterns
for desc in "${!CRITICAL_PATTERNS[@]}"; do
    pattern="${CRITICAL_PATTERNS[$desc]}"
    check_pattern "$pattern" "critical" "No $desc allowed" "$GO_FILE"
done

# Check fmt.Print outside main/tests
if [[ ! "$GO_FILE" =~ _test\.go$ ]] && [[ ! "$GO_FILE" =~ main\.go$ ]]; then
    if grep -Pq 'fmt\.Print(ln|f)?\(' "$GO_FILE" 2>/dev/null; then
        line_numbers=$(grep -Pn 'fmt\.Print(ln|f)?\(' "$GO_FILE" 2>/dev/null | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
        echo -e "${RED}❌ ERROR${NC}: fmt.Print should only be in main.go or tests"
        echo "   File: $GO_FILE"
        echo "   Lines: $line_numbers"
        echo "   Use proper logging (log, zap, etc.)"
        ((ERRORS++))
    fi
fi

# Check function length
awk '
/^func [a-zA-Z_]/ {
    fn_start = NR
    brace_count = 0
    in_function = 1
}
in_function && /{/ { brace_count++ }
in_function && /}/ {
    brace_count--
    if (brace_count == 0) {
        fn_length = NR - fn_start + 1
        if (fn_length > 50) {
            printf "Function too long: line %d, length %d lines\n", fn_start, fn_length
        }
        in_function = 0
    }
}
' "$GO_FILE" | while read line; do
    if [[ -n "$line" ]]; then
        echo -e "${RED}🚨 CRITICAL${NC}: $line"
        echo "   File: $GO_FILE"
        echo "   Limit: 50 lines per function"
        ((CRITICAL++))
        EXIT_CODE=1
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo "   🚨 Critical: $CRITICAL"
echo "   ❌ Errors: $ERRORS"
echo "   ⚠️  Warnings: $WARNINGS"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Check passed!${NC}"
else
    echo -e "${RED}❌ Check FAILED - fix critical issues${NC}"
fi

exit $EXIT_CODE
