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

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Configuration
MAX_FILE_LINES=100
MAX_FN_LINES=50

# Check if file provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <rust-file.rs>"
    exit 1
fi

RUST_FILE="$1"
CONTEXT_PATH="${2:-$RUST_FILE}"
DISPLAY_PATH="$CONTEXT_PATH"

if [ ! -f "$RUST_FILE" ]; then
    echo "Error: File not found: $RUST_FILE"
    exit 1
fi

# =============================================================================
# SANITIZATION: Strip comments and strings to avoid false positives
# =============================================================================
sanitize_rs() {
    local file="$1"

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
out = []
index = 0
length = len(text)
block_depth = 0
string_delim = None
escape = False
raw_hashes = None


def blank(character: str) -> str:
    return "\n" if character == "\n" else " "


while index < length:
    if block_depth:
        if text.startswith("/*", index):
            out.append("  ")
            block_depth += 1
            index += 2
            continue
        if text.startswith("*/", index):
            out.append("  ")
            block_depth -= 1
            index += 2
            continue
        out.append(blank(text[index]))
        index += 1
        continue

    if raw_hashes is not None:
        if text[index] == '"' and text.startswith("#" * raw_hashes, index + 1):
            out.append(" " * (1 + raw_hashes))
            index += 1 + raw_hashes
            raw_hashes = None
            continue
        out.append(blank(text[index]))
        index += 1
        continue

    if string_delim is not None:
        out.append(blank(text[index]))
        if escape:
            escape = False
        elif text[index] == "\\":
            escape = True
        elif text[index] == string_delim:
            string_delim = None
        index += 1
        continue

    if text.startswith("//", index):
        out.append("  ")
        index += 2
        while index < length and text[index] != "\n":
            out.append(" ")
            index += 1
        continue

    if text.startswith("/*", index):
        out.append("  ")
        block_depth = 1
        index += 2
        continue

    if text.startswith(("br", "rb"), index):
        start = index + 2
        hashes = 0
        while start + hashes < length and text[start + hashes] == "#":
            hashes += 1
        if start + hashes < length and text[start + hashes] == '"':
            out.append(" " * (3 + hashes))
            index = start + hashes + 1
            raw_hashes = hashes
            continue

    if text[index] == "r":
        cursor = index + 1
        hashes = 0
        while cursor < length and text[cursor] == "#":
            hashes += 1
            cursor += 1
        if cursor < length and text[cursor] == '"':
            out.append(" " * (2 + hashes))
            index = cursor + 1
            raw_hashes = hashes
            continue

    if text.startswith('b"', index):
        out.append("  ")
        index += 2
        string_delim = '"'
        escape = False
        continue

    if text[index] == '"':
        out.append(" ")
        index += 1
        string_delim = '"'
        escape = False
        continue

    out.append(text[index])
    index += 1

print("".join(out), end="")
PY
    else
        cat "$file"
    fi
}

is_test_file() {
    case "$CONTEXT_PATH" in
        */tests/*|*_test.rs) return 0 ;;
        *) return 1 ;;
    esac
}

is_crate_root_file() {
    local basename
    basename="$(basename "$CONTEXT_PATH")"

    case "$basename" in
        main.rs|lib.rs) return 0 ;;
        *) return 1 ;;
    esac
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
SANITIZED=$(sanitize_rs "$RUST_FILE")

IS_TEST_FILE=0
if is_test_file; then
    IS_TEST_FILE=1
    echo "ℹ️  Test file context detected: $CONTEXT_PATH"
fi

# Check 1: File length (code only, not comments)
# Count lines that still contain code after removing comments and strings.
TOTAL_LINES=$(wc -l < "$RUST_FILE")
CODE_LINES=$(printf '%s' "$SANITIZED" | grep -c '[^[:space:]]' || echo 0)
if [ "$CODE_LINES" -gt "$MAX_FILE_LINES" ]; then
    emit "$DISPLAY_PATH" 0 "File exceeds $MAX_FILE_LINES lines of code ($CODE_LINES lines, $TOTAL_LINES total)"
fi

# Check 2: Balance (braces, parens, brackets)
OB=$(printf '%s' "$SANITIZED" | grep -o '{' | wc -l | tr -d ' ') || true
CB=$(printf '%s' "$SANITIZED" | grep -o '}' | wc -l | tr -d ' ') || true
OP=$(printf '%s' "$SANITIZED" | grep -o '(' | wc -l | tr -d ' ') || true
CP=$(printf '%s' "$SANITIZED" | grep -o ')' | wc -l | tr -d ' ') || true
OS=$(printf '%s' "$SANITIZED" | grep -o '\[' | wc -l | tr -d ' ') || true
CS=$(printf '%s' "$SANITIZED" | grep -o '\]' | wc -l | tr -d ' ') || true

[ "$OB" -ne "$CB" ] && emit "$DISPLAY_PATH" 0 "Brace mismatch: {=$OB }=$CB"
[ "$OP" -ne "$CP" ] && emit "$DISPLAY_PATH" 0 "Paren mismatch: (=$OP )=$CP"
[ "$OS" -ne "$CS" ] && emit "$DISPLAY_PATH" 0 "Bracket mismatch: [=$OS ]=$CS"

# Check 3: ALWAYS forbidden patterns (CRITICAL)
# Unsafe / UB magnets
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "unsafe/UB-magnet forbidden"
done < <(printf '%s' "$SANITIZED" | grep -nE '\bunsafe\b|\btransmute\b|\bzeroed\b|\bassume_init\b|\bget_unchecked\b|\bfrom_utf8_unchecked\b|intrinsics::|\baddr_of\b|\bstatic[[:space:]]+mut\b|\bUnsafeCell\b' || true)

# Todo/unimplemented markers - check RAW file (not sanitized) since TODO in comments should also be caught
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "unfinished marker/macro forbidden"
done < <(grep -nE '\bTODO\b|\bFIXME\b|\bHACK\b|\bXXX\b|\bunimplemented!\(' "$RUST_FILE" || true)

# todo! macro
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "todo! forbidden"
done < <(printf '%s' "$SANITIZED" | grep -nE '\btodo!\(' || true)

# Check 4: Panic/unwrap/assert sources - production only
if [ "$IS_TEST_FILE" -eq 0 ]; then
    while IFS=: read -r ln line; do
        if echo "$line" | grep -qE '\.unwrap\('; then
            emit "$DISPLAY_PATH" "$ln" "unwrap() forbidden - use ? or proper error handling"
        elif echo "$line" | grep -qE '\.expect\('; then
            emit "$DISPLAY_PATH" "$ln" "expect() forbidden - use ? or proper error handling"
        elif echo "$line" | grep -qE '\bpanic!\b'; then
            emit "$DISPLAY_PATH" "$ln" "panic!() forbidden - return Result instead"
        elif echo "$line" | grep -qE '\bunreachable!\b'; then
            emit "$DISPLAY_PATH" "$ln" "unreachable!() forbidden"
        elif echo "$line" | grep -qE '\bassert!\b|\bassert_eq!\b|\bdebug_assert!\b'; then
            emit "$DISPLAY_PATH" "$ln" "assert macros forbidden outside test files"
        fi
    done < <(printf '%s' "$SANITIZED" | grep -nE '\bpanic!\b|\bunreachable!\b|\bassert!\b|\bassert_eq!\b|\bdebug_assert!\b|\.unwrap\(|\.expect\(' || true)
fi

# unwrap_or variants (specific messages)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "unwrap_or() forbidden - handle error explicitly"
done < <(printf '%s' "$SANITIZED" | grep -nE '\.unwrap_or\s*\(' || true)

while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "unwrap_or_else() forbidden - handle error explicitly"
done < <(printf '%s' "$SANITIZED" | grep -nE '\.unwrap_or_else\s*\(' || true)

# Default::default()
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "Default::default() forbidden"
done < <(printf '%s' "$SANITIZED" | grep -nE '\bDefault::default\s*\(\s*\)' || true)

# #[allow(...)] forbidden
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "#[allow(...)] forbidden"
done < <(printf '%s' "$SANITIZED" | grep -nE '^\s*#\s*\[\s*allow\s*\(' || true)

# Check 5: dbg! macro (always forbidden)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "dbg!() forbidden"
done < <(printf '%s' "$SANITIZED" | grep -nE '\bdbg!\s*\(' || true)

# Check 6: println/eprintln - production only
if [ "$IS_TEST_FILE" -eq 0 ]; then
    while IFS=: read -r ln _; do
        emit "$DISPLAY_PATH" "$ln" "println/eprintln forbidden"
    done < <(printf '%s' "$SANITIZED" | grep -nE '\b(eprintln|println)!' || true)
fi

# Check 7: Mock patterns - ALWAYS forbidden
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "mock/fake/stub pattern forbidden"
done < <(printf '%s' "$SANITIZED" | grep -nE '(mock|Mock|fake|Fake|stub|Stub|dummy|Dummy)\s*(struct|impl|fn|mod)' || true)

# Check 8: Clone on copy (ERROR)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "unnecessary clone on copy"
done < <(printf '%s' "$SANITIZED" | grep -nE '\.clone\(\)' || true)

# Check 9: unwrap_or_default (ERROR)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "unwrap_or_default should be avoided"
done < <(printf '%s' "$SANITIZED" | grep -nE '\.unwrap_or_default\(\)' || true)

# Check 10: as_str().to_string() (ERROR)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "use to_owned() instead of as_str().to_string()"
done < <(printf '%s' "$SANITIZED" | grep -nE '\.as_str\(\)\.to_string\(\)' || true)

# Check 11: Dyn trait misuse (WARNING/CRITICAL)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "dyn trait-object misuse in generics"
done < <(printf '%s' "$SANITIZED" | grep -nE '<[[:space:]]*\( *dyn\b|\( *dyn\b[^)]*\) *>' || true)

# Check 12: Single-letter variables (WARNING) - show full context
# Allow single-letter vars in for loops: for i in, for j in, etc.
while IFS=: read -r ln line; do
    id=$(echo "$line" | sed -nE 's/^\s*let\s+([A-Za-z])\b.*/\1/p')
    [[ -z "$id" ]] && continue
    # Allow i, j, k, x, y, z everywhere
    case "$id" in i|j|k|x|y|z) continue ;; esac
    # Allow single-letter vars in for loops: for i in 0..10, for item in items
    if echo "$line" | grep -qE '^\s*for\s+[a-z]\b'; then
        continue
    fi
    emit "$DISPLAY_PATH" "$ln" "single-letter var '$id' - use descriptive name (e.g., '$id' -> $(echo "$id" | sed -e 's/a/alpha/g' -e 's/b/beta/g' -e 's/c/count/g' -e 's/r/result/g' -e 's/s/source/g' -e 's/t/temp/g'))"
done < <(printf '%s' "$SANITIZED" | grep -nE '^\s*let\s+[A-Za-z]\b' || true)

# Check 13: #![forbid(unsafe_code)] at crate root (only main.rs/lib.rs)
if is_crate_root_file && ! head -5 "$RUST_FILE" | grep -q '^#!\[forbid(unsafe_code)\]'; then
    emit "$DISPLAY_PATH" 0 "Missing #![forbid(unsafe_code)] at crate root"
fi

# Check 14: Dynamic allocation forbidden (vec!, Box, HashMap, Arc, Rc)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "dynamic allocation forbidden (vec!/Box/HashMap/Arc/Rc)"
done < <(printf '%s' "$SANITIZED" | grep -nE '\b(vec!|Box::|HashMap::|Arc::|Rc::)\b' || true)

# Check 15: Direct array indexing forbidden (exclude vec!, array literals, and 2D access)
while IFS=: read -r ln line; do
    # Skip lines with vec! macro
    if echo "$line" | grep -qE 'vec!'; then
        continue
    fi
    # Skip attributes such as #[test]
    if echo "$line" | grep -qE '^\s*#\['; then
        continue
    fi
    # Skip array literal access patterns like [1, 2, 3][0] or ["a", "b"][1]
    if echo "$line" | grep -qE '\[\s*\[[^\]]+\]\s*\]\s*\['; then
        continue
    fi
    # Skip 2D array access like matrix[i][j] - this is intentional in the rules
    if echo "$line" | grep -qE '\]\s*\['; then
        continue
    fi
    # Extract just the indexing part for context
    match=$(echo "$line" | grep -oE '\[[0-9]+\]|\[[a-z_][a-z0-9_]*\]' | head -1)
    [[ -z "$match" ]] && continue
    emit "$DISPLAY_PATH" "$ln" "direct indexing $match forbidden - use .get() instead"
done < <(printf '%s' "$SANITIZED" | grep -nE '\[[0-9]+\]|\[[a-z_][a-z0-9_]*\]' || true)

# Check 16: Unsafe blocks forbidden
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "unsafe block forbidden"
done < <(printf '%s' "$SANITIZED" | grep -nE '\bunsafe\s*\{' || true)

# Check 17: Bare arithmetic operators forbidden - show which operator
# Match operators with or without surrounding spaces (but not -> or =>)
while IFS=: read -r ln line; do
    # Find which operator was used - check for -> or => first (not arithmetic)
    if echo "$line" | grep -qE -- '->|=>'; then
        continue
    fi
    if echo "$line" | grep -qP '(?<![[:alnum:]_])\+(?![[:alnum:]_])'; then
        op="+"
    elif echo "$line" | grep -qP '(?<![[:alnum:]_])\-(?![[:alnum:]_])'; then
        op="-"
    elif echo "$line" | grep -qP '(?<![[:alnum:]_])\*(?![[:alnum:]_])'; then
        op="*"
    elif echo "$line" | grep -qP '(?<![[:alnum:]_])/(?![[:alnum:]_])'; then
        op="/"
    elif echo "$line" | grep -qP '(?<![[:alnum:]_])%(?![[:alnum:]_])'; then
        op="%"
    else
        op="arithmetic"
    fi
    emit "$DISPLAY_PATH" "$ln" "bare '$op' operator forbidden - use .saturating_add()/.saturating_sub() instead"
done < <(printf '%s' "$SANITIZED" | grep -nP '(?<![[:alnum:]_])[\+\-\*/%](?![[:alnum:]_])' || true)

# Check 18: Function length (WARNING)
printf '%s' "$SANITIZED" | awk -v file="$DISPLAY_PATH" -v limit="$MAX_FN_LINES" '
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
    emit "$DISPLAY_PATH" "$ln" "function too long"
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Check passed!${NC}"
else
    echo -e "${RED}❌ Check FAILED${NC}"
fi

exit $EXIT_CODE
