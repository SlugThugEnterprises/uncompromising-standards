#!/usr/bin/env bash
# =============================================================================
# JS/TS ENFORCER - Used by AI agent hooks
# Pure bash/regex - no compilation
# =============================================================================
set -uo pipefail

EXIT_CODE=0

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Configuration
MAX_FILE_LINES=200
MAX_FN_LINES=50
MAX_FN_COUNT=4
MAX_NESTING=3

if [ $# -eq 0 ]; then
    echo "Usage: $0 <js-or-ts-file>"
    exit 1
fi

JS_FILE="$1"
CONTEXT_PATH="${2:-$JS_FILE}"
DISPLAY_PATH="$CONTEXT_PATH"

if [ ! -f "$JS_FILE" ]; then
    echo "Error: File not found: $JS_FILE"
    exit 1
fi

emit() {
    local file="$1"
    local line="$2"
    local msg="$3"

    echo -e "${RED}❌ FAIL${NC}: $msg"
    echo "   File: $file"
    [[ "$line" != "0" ]] && echo "   Line: $line"
    EXIT_CODE=1
}

warn() {
    local file="$1"
    local line="$2"
    local msg="$3"

    echo -e "${YELLOW}⚠ WARN${NC}: $msg"
    echo "   File: $file"
    [[ "$line" != "0" ]] && echo "   Line: $line"
}

is_test_file() {
    case "$CONTEXT_PATH" in
        */tests/*|*_test.*|*\.test\.*|*\\.spec\.*) return 0 ;;
        *) return 1 ;;
    esac
}

echo "🔍 Fast-checking JS/TS file: $JS_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

IS_TEST=0
if is_test_file; then
    IS_TEST=1
    echo "ℹ️  Test file detected"
fi

# Check 1: File length
TOTAL_LINES=$(wc -l < "$JS_FILE")
if [ "$TOTAL_LINES" -gt "$MAX_FILE_LINES" ]; then
    emit "$DISPLAY_PATH" 0 "File exceeds $MAX_FILE_LINES lines ($TOTAL_LINES lines)"
fi

# Check 2: Balance (braces, parens, brackets)
OB=$(grep -c '{' "$JS_FILE")
CB=$(grep -c '}' "$JS_FILE")
OP=$(grep -c '(' "$JS_FILE")
CP=$(grep -c ')' "$JS_FILE")
OS=$(grep -c '\[' "$JS_FILE")
CS=$(grep -c '\]' "$JS_FILE")

[ "${OB}" -ne "${CB}" ] && emit "$DISPLAY_PATH" 0 "Brace mismatch: {=${OB} }=${CB}"
[ "${OP}" -ne "${CP}" ] && emit "$DISPLAY_PATH" 0 "Paren mismatch: (=${OP} )=${CP}"
[ "${OS}" -ne "${CS}" ] && emit "$DISPLAY_PATH" 0 "Bracket mismatch: [=${OS} ]=${CS}"

# Check 3: Function count
FN1=$(grep -cE '^\s*(async\s+)?function\s+' "$JS_FILE")
FN2=$(grep -cE '=>\s*{' "$JS_FILE")
FN3=$(grep -cE '^\s*\w+\s*\([^)]*\)\s*=>' "$JS_FILE")
FN_COUNT=$((FN1 + FN2 + FN3))
if [ "$FN_COUNT" -gt "$MAX_FN_COUNT" ]; then
    emit "$DISPLAY_PATH" 0 "File exceeds $MAX_FN_COUNT functions ($FN_COUNT found)"
fi

# Check 4: TODO/FIXME/HACK markers (check raw file to catch comments)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "TODO/FIXME/HACK marker forbidden"
done < <(grep -nE '\bTODO\b|\bFIXME\b|\bHACK\b|\bXXX\b' "$JS_FILE" || true)

# Check 5: var keyword (must use const/let)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "var forbidden - use const or let"
done < <(grep -nE '\bvar\s+' "$JS_FILE" || true)

# Check 6: eval and new Function (code injection risks)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "eval() forbidden - code injection risk"
done < <(grep -nE '\beval\s*\(' "$JS_FILE" || true)

while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "new Function() forbidden - code injection risk"
done < <(grep -nE 'new\s+Function\s*\(' "$JS_FILE" || true)

# Check 7: setTimeout with string (indirect eval)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "setTimeout/setInterval with string forbidden - indirect eval risk"
done < <(grep -nE 'setTimeout\s*\(\s*["'\'']' "$JS_FILE" || true)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "setTimeout/setInterval with string forbidden - indirect eval risk"
done < <(grep -nE 'setInterval\s*\(\s*["'\'']' "$JS_FILE" || true)

# Check 8: innerHTML / outerHTML (XSS risk)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "innerHTML/outerHTML forbidden - XSS risk, use textContent"
done < <(grep -nE '\.(innerHTML|outerHTML)\s*=' "$JS_FILE" || true)

# Check 9: document.write
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "document.write forbidden - XSS risk"
done < <(grep -nE '\bdocument\.write\s*\(' "$JS_FILE" || true)

# Check 10: console.log in production
if [ "$IS_TEST" -eq 0 ]; then
    while IFS=: read -r ln _; do
        emit "$DISPLAY_PATH" "$ln" "console.log forbidden in production - use console.warn/error or remove"
    done < <(grep -nE '\bconsole\.log\s*\(' "$JS_FILE" || true)
fi

# Check 11: alert/confirm/prompt (UI blocking)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "alert/confirm/prompt forbidden - blocks UI thread"
done < <(grep -nE '\b(alert|confirm|prompt)\s*\(' "$JS_FILE" || true)

# Check 12: == instead of === (type coercion bugs)
# Match == with space before or after (likely loose equality, not assignment)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "== forbidden - use === for strict equality"
done < <(grep -nE ' == | ==|== ' "$JS_FILE" || true)

# Check 13: TypeScript specific - any type
if [[ "$JS_FILE" == *.ts ]] || [[ "$JS_FILE" == *.tsx ]]; then
    while IFS=: read -r ln _; do
        emit "$DISPLAY_PATH" "$ln" "any type forbidden - use explicit type annotation"
    done < <(grep -nE ':\s*any\b' "$JS_FILE" || true)

    while IFS=: read -r ln _; do
        emit "$DISPLAY_PATH" "$ln" "@ts-ignore forbidden - fix the underlying issue"
    done < <(grep -nE '@ts-ignore' "$JS_FILE" || true)

    while IFS=: read -r ln _; do
        emit "$DISPLAY_PATH" "$ln" "@ts-nocheck forbidden"
    done < <(grep -nE '@ts-nocheck' "$JS_FILE" || true)
fi

# Check 14: require() instead of import
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "require() forbidden - use ES import"
done < <(grep -nE '\brequire\s*\(' "$JS_FILE" || true)

# Check 15: Common bug patterns
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "= in condition likely bug - use === or =="
done < <(grep -nE 'if\s*\(\s*\w+\s*=\s*\w+\s*\)' "$JS_FILE" || true)

# Check 16: Magic numbers
while IFS=: read -r ln line; do
    # Allow in test files
    [ "$IS_TEST" -eq 1 ] && continue
    # Skip line comments
    if echo "$line" | grep -qE '^\s*//'; then
        continue
    fi
    emit "$DISPLAY_PATH" "$ln" "magic number forbidden - use named constant"
done < <(grep -nE '[^A-Za-z_][0-9]{3,}[^A-Za-z_]' "$JS_FILE" | grep -vE '^[0-9]+$' || true)

# Check 17: Single-letter variables (except loop counters)
while IFS=: read -r ln line; do
    var=$(echo "$line" | sed -nE 's/^\s*(const|let|var)\s+([A-Za-z])\b.*/\2/p')
    [[ -z "$var" ]] && continue
    case "$var" in i|j|k|x|y|z) continue ;; esac
    if echo "$line" | grep -qE '^\s*for\s*\(\s*[a-z]\s*'; then
        continue
    fi
    warn "$DISPLAY_PATH" "$ln" "single-letter var '$var' - use descriptive name"
done < <(grep -nE '^\s*(const|let|var)\s+[A-Za-z]\s*[=;,]' "$JS_FILE" || true)

# Check 18: Function length - warn if any function exceeds limit
while IFS=: read -r ln _; do
    content=$(sed -n "${ln},\$p" "$JS_FILE" | awk '
        function start_fn(line) { return (line ~ /^\s*(async\s+)?function\s+/) }
        BEGIN { in_fn=0; depth=0; start=0; }
        {
            if (!in_fn && start_fn($0)) { in_fn=1; start=NR; depth=0 }
            if (in_fn) {
                for (i=1;i<=length($0);i++) {
                    c=substr($0,i,1)
                    if (c=="{") depth++
                    else if (c=="}") depth--
                }
                if (depth==0 && NR>start) {
                    len=NR-start
                    if (len>'"$MAX_FN_LINES"') {
                        printf "WARN: %s:%d: function %d lines > %d\n", "'"$DISPLAY_PATH"'", start, len, '"$MAX_FN_LINES"'
                    }
                    in_fn=0
                }
            }
        }
    ')
    [ -n "$content" ] && warn "$DISPLAY_PATH" "$ln" "function too long"
done < <(grep -nE '^\s*(async\s+)?function\s+' "$JS_FILE" || true)

# Check 19: Nested callbacks - count { increase
NESTING=0
MAX_ACTUAL=0
while IFS= read -r line; do
    opens=$(echo "$line" | grep -o '{' | wc -l)
    closes=$(echo "$line" | grep -o '}' | wc -l)
    NESTING=$((NESTING + opens - closes))
    [ "$NESTING" -gt "$MAX_ACTUAL" ] && MAX_ACTUAL=$NESTING
done < "$JS_FILE"
if [ "$MAX_ACTUAL" -gt "$MAX_NESTING" ]; then
    emit "$DISPLAY_PATH" 0 "Nesting depth $MAX_ACTUAL exceeds max $MAX_NESTING"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Check passed!${NC}"
else
    echo -e "${RED}❌ Check FAILED${NC}"
fi

exit $EXIT_CODE
