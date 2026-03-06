#!/usr/bin/env bash
# =============================================================================
# REAL-TIME ENFORCER - Used by AI agent hooks
# Called per-file by: pre-write, post-write, pre-commit hooks
# Thread-safe: No shared state, no temp files
# =============================================================================
set -uo pipefail

# Fast Rust pattern checker - lightweight alternative to rust-analyzer
# Uses regex patterns to catch common issues without full compilation
# Enhanced with sanitization and balance checking from DO-NOT-EDIT checker

EXIT_CODE=0
WARNINGS=0
ERRORS=0
CRITICAL=0

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Configuration
MAX_FILE_LINES=200
MAX_FN_LINES=50
DOC_LOOKBACK=3

# Check if file provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <rust-file.rs>"
    exit 1
fi

RUST_FILE="$1"

if [ ! -f "$RUST_FILE" ]; then
    echo "Error: File not found: $RUST_FILE"
    exit 1
fi

# =============================================================================
# SANITIZATION: Strip comments and strings to avoid false positives
# =============================================================================
sanitize_rs() {
    # Strip line comments, block comments, strings, and chars
    # Use single quotes to prevent ! expansion
    sed -e 's://.*$::' \
        -e 's:/\*.*\*/::g' \
        -e 's:"[^"\\]*\\.":_:g' \
        -e 's:"[^"]*":__:g' \
        -e 's:'\''[^'\'']*'\'':__:g'
}

# =============================================================================
# HELPERS
# =============================================================================
emit() {
    local file="$1"
    local line="$2"
    local msg="$3"

    echo -e "${RED}❌ FAIL${NC}: $msg"
    echo "   File: $file"
    [[ "$line" != "0" ]] && echo "   Line: $line"
    EXIT_CODE=1
}

# =============================================================================
# CHECKS
# =============================================================================

echo "🔍 Fast-checking Rust file: $RUST_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get sanitized content (without strings/comments)
SANITIZED=$(sanitize_rs < "$RUST_FILE")

# Check 1: File length
LINE_COUNT=$(wc -l < "$RUST_FILE")
if [ $LINE_COUNT -gt $MAX_FILE_LINES ]; then
    emit "$RUST_FILE" 0 "File exceeds $MAX_FILE_LINES lines ($LINE_COUNT lines)"
fi

# Check 2: Balance (braces, parens, brackets)
OB=$(echo "$SANITIZED" | grep -o '{' | wc -l | tr -d ' ') || true
CB=$(echo "$SANITIZED" | grep -o '}' | wc -l | tr -d ' ') || true
OP=$(echo "$SANITIZED" | grep -o '(' | wc -l | tr -d ' ') || true
CP=$(echo "$SANITIZED" | grep -o ')' | wc -l | tr -d ' ') || true
OS=$(echo "$SANITIZED" | grep -o '\[' | wc -l | tr -d ' ') || true
CS=$(echo "$SANITIZED" | grep -o '\]' | wc -l | tr -d ' ') || true

[ "$OB" -ne "$CB" ] && emit "$RUST_FILE" 0 "Brace mismatch: {=$OB }=$CB"
[ "$OP" -ne "$CP" ] && emit "$RUST_FILE" 0 "Paren mismatch: (=$OP )=$CP"
[ "$OS" -ne "$CS" ] && emit "$RUST_FILE" 0 "Bracket mismatch: [=$OS ]=$CS"

# Check 3: ALWAYS forbidden patterns (CRITICAL)
# Unsafe / UB magnets
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "unsafe/UB-magnet forbidden"
done < <(grep -nE '\bunsafe\b|\btransmute\b|\bzeroed\b|\bassume_init\b|\bget_unchecked\b|\bfrom_utf8_unchecked\b|intrinsics::|\baddr_of\b|\bstatic[[:space:]]+mut\b|\bUnsafeCell\b' <<<"$SANITIZED" || true)

# Todo/unimplemented markers - check RAW file (not sanitized) since TODO in comments should also be caught
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "unfinished marker/macro forbidden"
done < <(grep -nE '\bTODO\b|\bFIXME\b|\bHACK\b|\bXXX\b|\bunimplemented!\(' "$RUST_FILE" || true)

# todo! macro
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "todo! forbidden"
done < <(grep -nE '\btodo!\(' <<<"$SANITIZED" || true)

# Check 4: Panic/unwrap/assert sources - ALWAYS forbidden (specific messages)
while IFS=: read -r ln line; do
    if echo "$line" | grep -qE '\.unwrap\('; then
        emit "$RUST_FILE" "$ln" "unwrap() forbidden - use ? or proper error handling"
    elif echo "$line" | grep -qE '\.expect\('; then
        emit "$RUST_FILE" "$ln" "expect() forbidden - use ? or proper error handling"
    elif echo "$line" | grep -qE '\bpanic!\b'; then
        emit "$RUST_FILE" "$ln" "panic!() forbidden - return Result instead"
    elif echo "$line" | grep -qE '\bunreachable!\b'; then
        emit "$RUST_FILE" "$ln" "unreachable!() forbidden"
    elif echo "$line" | grep -qE '\bassert!\b|\bassert_eq!\b|\bdebug_assert!\b'; then
        emit "$RUST_FILE" "$ln" "assert macros forbidden"
    fi
done < <(grep -nE '\bpanic!\b|\bunreachable!\b|\bassert!\b|\bassert_eq!\b|\bdebug_assert!\b|\.unwrap\(|\.expect\(' <<<"$SANITIZED" || true)

# unwrap_or variants (specific messages)
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "unwrap_or() forbidden - handle error explicitly"
done < <(grep -nE '\.unwrap_or\s*\(' <<<"$SANITIZED" || true)

while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "unwrap_or_else() forbidden - handle error explicitly"
done < <(grep -nE '\.unwrap_or_else\s*\(' <<<"$SANITIZED" || true)

# Default::default()
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "Default::default() forbidden"
done < <(grep -nE '\bDefault::default\s*\(\s*\)' <<<"$SANITIZED" || true)

# #[allow(...)] forbidden
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "#[allow(...)] forbidden"
done < <(grep -nE '^\s*#\s*\[\s*allow\s*\(' <<<"$SANITIZED" || true)

# #[cfg(test)] forbidden
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "#[cfg(test)] forbidden"
done < <(grep -nE '^\s*#\s*\[\s*cfg\s*\(\s*test\s*\)\s*\]' <<<"$SANITIZED" || true)

# Check 5: dbg! macro (always forbidden)
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "dbg!() forbidden"
done < <(grep -nE '\bdbg!\s*\(' <<<"$SANITIZED" || true)

# Check 6: println/eprintln - ALWAYS forbidden
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "println/eprintln forbidden"
done < <(grep -nE '\b(eprintln|println)!' <<<"$SANITIZED" || true)

# Check 7: Mock patterns - ALWAYS forbidden
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "mock/fake/stub pattern forbidden"
done < <(grep -nE '(mock|Mock|fake|Fake|stub|Stub|dummy|Dummy)\s*(struct|impl|fn|mod)' <<<"$SANITIZED" || true)

# Check 8: Clone on copy (ERROR)
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "unnecessary clone on copy"
done < <(grep -nE '\.clone\(\)' <<<"$SANITIZED" || true)

# Check 9: unwrap_or_default (ERROR)
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "unwrap_or_default should be avoided"
done < <(grep -nE '\.unwrap_or_default\(\)' <<<"$SANITIZED" || true)

# Check 10: as_str().to_string() (ERROR)
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "use to_owned() instead of as_str().to_string()"
done < <(grep -nE '\.as_str\(\)\.to_string\(\)' <<<"$SANITIZED" || true)

# Check 11: Dyn trait misuse (WARNING/CRITICAL)
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "dyn trait-object misuse in generics"
done < <(grep -nE '<[[:space:]]*\( *dyn\b|\( *dyn\b[^)]*\) *>' <<<"$SANITIZED" || true)

# Check 12: Single-letter variables (WARNING) - show full context
while IFS=: read -r ln line; do
    id=$(echo "$line" | sed -nE 's/^\s*let\s+([A-Za-z])\b.*/\1/p')
    [[ -z "$id" ]] && continue
    case "$id" in i|j|k|x|y|z) continue ;; esac
    # Get the full line from original file for context
    context=$(sed -n "${ln}p" "$RUST_FILE" | sed 's/[[:space:]]*$//')
    emit "$RUST_FILE" "$ln" "single-letter var '$id' - use descriptive name (e.g., '$id' -> $(echo "$id" | sed -e 's/a/alpha/g' -e 's/b/beta/g' -e 's/c/count/g' -e 's/r/result/g' -e 's/s/source/g' -e 's/t/temp/g'))"
done < <(grep -nE '^\s*let\s+[A-Za-z]\b' <<<"$SANITIZED" || true)

# Check 14: #![forbid(unsafe_code)] at crate root (must be in first file)
if ! head -5 "$RUST_FILE" | grep -q '^#!\[forbid(unsafe_code)\]'; then
    emit "$RUST_FILE" 1 "Missing #![forbid(unsafe_code)] at crate root"
fi

# Check 15: Dynamic allocation forbidden (vec!, Box, HashMap, Arc, Rc)
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "dynamic allocation forbidden (vec!/Box/HashMap/Arc/Rc)"
done < <(grep -nE '\b(vec!|Box::|HashMap::|Arc::|Rc::)\b' <<< "$SANITIZED" || true)

# Check 16: Direct array indexing forbidden (exclude vec! and array literals)
while IFS=: read -r ln line; do
    # Skip lines with vec! or array literals
    if echo "$line" | grep -qE 'vec!|\[\s*\[|='; then
        continue
    fi
    # Extract just the indexing part for context
    match=$(echo "$line" | grep -oE '\[[0-9]+\]|\[[a-z_][a-z0-9_]*\]' | head -1)
    [[ -z "$match" ]] && continue
    emit "$RUST_FILE" "$ln" "direct indexing $match forbidden - use .get() instead"
done < <(grep -nE '\[[0-9]+\]|\[[a-z_][a-z0-9_]*\]' <<< "$SANITIZED" || true)

# Check 17: Unsafe blocks forbidden
while IFS=: read -r ln _; do
    emit "$RUST_FILE" "$ln" "unsafe block forbidden"
done < <(grep -nE '\bunsafe\s*\{' <<< "$SANITIZED" || true)

# Check 18: Bare arithmetic operators forbidden - show which operator
while IFS=: read -r ln line; do
    # Find which operator was used
    if echo "$line" | grep -qE '\+'; then
        op="+"
    elif echo "$line" | grep -qE '\- '; then
        op="-"
    elif echo "$line" | grep -qE '\*'; then
        op="*"
    elif echo "$line" | grep -qE '/'; then
        op="/"
    elif echo "$line" | grep -qE '%'; then
        op="%"
    else
        op="arithmetic"
    fi
    emit "$RUST_FILE" "$ln" "bare '$op' operator forbidden - use .saturating_add()/.saturating_sub() instead"
done < <(grep -nE ' \+ | \- | \* | / | % ' <<< "$SANITIZED" | grep -vE '^\s*//' || true)

# Check 13: Function length (WARNING)
echo "$SANITIZED" | awk -v file="$RUST_FILE" -v limit="$MAX_FN_LINES" '
function start_fn(line) { return (line ~ /(^|[[:space:]])fn[[:space:]]+[A-Za-z0-9_]+/) }
BEGIN { in_fn=0; depth=0; start=0; }
{
    line=$0
    if (!in_fn && start_fn(line)) { in_fn=1; start=NR; depth=0 }
    if (in_fn) {
        for (i=1;i<=length(line);i++) {
            c=substr(line,i,1)
            if (c=="{") depth++
            else if (c=="}") depth--
        }
        if (depth==0 && NR>start) {
            len=NR-start
            if (len>limit) {
                printf "WARNING: %s:%d: function %d lines > %d\n", file, start, len, limit
            }
            in_fn=0
        }
    }
}
' | while IFS= read -r line; do
    # Extract line number and message
    ln=$(echo "$line" | cut -d: -f2)
    emit "$RUST_FILE" "$ln" "function too long"
done

# Check 14: Public items missing docs (WARNING)
# This is complex, so we skip for performance - could be added later

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Check passed!${NC}"
else
    echo -e "${RED}❌ Check FAILED${NC}"
fi

exit $EXIT_CODE
