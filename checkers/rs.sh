#!/usr/bin/env bash
# =============================================================================
# REAL-TIME ENFORCER - Used by AI agent hooks
# Called per-file by: pre-write, post-write, pre-commit hooks
# Thread-safe: No shared state, no temp files
# =============================================================================
set -uo pipefail

# Fast Rust pattern checker - lightweight alternative to rust-analyzer
# Uses regex patterns to catch common issues without full compilation
# Tailored for UI/rendering/designer applications

EXIT_CODE=0

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Configuration
MAX_FILE_LINES=400
MAX_FN_LINES=80
MAX_FN_COUNT=6

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

is_render_file() {
    case "$CONTEXT_PATH" in
        */render/*|*/canvas/*|*/ui/view/*|*/ui/editor/*) return 0 ;;
        *) return 1 ;;
    esac
}

is_state_file() {
    case "$CONTEXT_PATH" in
        */app_state/*|*/state/*|*/ui/context.rs) return 0 ;;
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

warn() {
    local file="$1"
    local line="$2"
    local msg="$3"

    echo -e "${YELLOW}⚠ WARN${NC}: $msg"
    echo "   File: $file"
    [[ "$line" != "0" ]] && echo "   Line: $line"
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

IS_RENDER_FILE=0
if is_render_file; then
    IS_RENDER_FILE=1
    echo "ℹ️  Render/UI file context detected: $CONTEXT_PATH"
fi

IS_STATE_FILE=0
if is_state_file; then
    IS_STATE_FILE=1
    echo "ℹ️  State file context detected: $CONTEXT_PATH"
fi

# Check 1: File length (code only, not comments)
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
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "unsafe/UB-magnet forbidden"
done < <(printf '%s' "$SANITIZED" | grep -nE '\bunsafe\b|\btransmute\b|\bzeroed\b|\bassume_init\b|\bget_unchecked\b|\bfrom_utf8_unchecked\b|intrinsics::|\baddr_of\b|\bstatic[[:space:]]+mut\b|\bUnsafeCell\b' || true)

# Todo/unimplemented markers - check RAW file so comments are caught too
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

# unwrap_or variants
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "unwrap_or() forbidden - handle error explicitly"
done < <(printf '%s' "$SANITIZED" | grep -nE '\.unwrap_or\s*\(' || true)

while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "unwrap_or_else() forbidden - handle error explicitly"
done < <(printf '%s' "$SANITIZED" | grep -nE '\.unwrap_or_else\s*\(' || true)

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

# Check 8: unwrap_or_default (WARN)
while IFS=: read -r ln _; do
    warn "$DISPLAY_PATH" "$ln" "unwrap_or_default used - verify silent fallback is truly correct"
done < <(printf '%s' "$SANITIZED" | grep -nE '\.unwrap_or_default\(\)' || true)

# Check 9: as_str().to_string() (WARN)
while IFS=: read -r ln _; do
    warn "$DISPLAY_PATH" "$ln" "use to_owned() instead of as_str().to_string()"
done < <(printf '%s' "$SANITIZED" | grep -nE '\.as_str\(\)\.to_string\(\)' || true)

# Check 10: Dyn trait misuse (FAIL)
while IFS=: read -r ln _; do
    emit "$DISPLAY_PATH" "$ln" "dyn trait-object misuse in generics"
done < <(printf '%s' "$SANITIZED" | grep -nE '<[[:space:]]*\( *dyn\b|\( *dyn\b[^)]*\) *>' || true)

# Check 11: Single-letter variables (WARN)
while IFS=: read -r ln line; do
    id=$(echo "$line" | sed -nE 's/^\s*let\s+([A-Za-z])\b.*/\1/p')
    [[ -z "$id" ]] && continue
    case "$id" in i|j|k|x|y|z) continue ;; esac
    if echo "$line" | grep -qE '^\s*for\s+[a-z]\b'; then
        continue
    fi
    warn "$DISPLAY_PATH" "$ln" "single-letter var '$id' - use descriptive name"
done < <(printf '%s' "$SANITIZED" | grep -nE '^\s*let\s+[A-Za-z]\b' || true)

# Check 12: #![forbid(unsafe_code)] at crate root
if is_crate_root_file && ! head -5 "$RUST_FILE" | grep -q '^#!\[forbid(unsafe_code)\]'; then
    emit "$DISPLAY_PATH" 0 "Missing #![forbid(unsafe_code)] at crate root"
fi

# Check 13: Render determinism hazards in render files
if [ "$IS_RENDER_FILE" -eq 1 ] && [ "$IS_TEST_FILE" -eq 0 ]; then
    while IFS=: read -r ln _; do
        emit "$DISPLAY_PATH" "$ln" "nondeterministic source forbidden in render path (rand/time/thread_rng)"
    done < <(printf '%s' "$SANITIZED" | grep -nE '\brand::|\bthread_rng\b|\bSystemTime::now\b|\bInstant::now\b|\brandom\s*\(' || true)

    while IFS=: read -r ln _; do
        emit "$DISPLAY_PATH" "$ln" "borrow_mut() forbidden in render path - render must use stable snapshot"
    done < <(printf '%s' "$SANITIZED" | grep -nE '\.borrow_mut\s*\(' || true)

    while IFS=: read -r ln _; do
        warn "$DISPLAY_PATH" "$ln" "float equality in render path - verify tolerance-based comparison is not needed"
    done < <(printf '%s' "$SANITIZED" | grep -nE '==.*(f32|f64)|!=.*(f32|f64)' || true)
fi

# Check 14: State mutation hazards in state/UI files
if [ "$IS_STATE_FILE" -eq 1 ] && [ "$IS_TEST_FILE" -eq 0 ]; then
    while IFS=: read -r ln _; do
        warn "$DISPLAY_PATH" "$ln" "Rc<RefCell<...>> detected - verify mutation boundaries are narrow and controlled"
    done < <(printf '%s' "$SANITIZED" | grep -nE 'Rc\s*<\s*RefCell\s*<' || true)
fi

# Check 15: Function length (WARN)
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
    ln=$(echo "$line" | cut -d: -f2)
    warn "$DISPLAY_PATH" "$ln" "function too long"
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Check passed!${NC}"
else
    echo -e "${RED}❌ Check FAILED${NC}"
fi

exit $EXIT_CODE
