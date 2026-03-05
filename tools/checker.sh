#!/bin/bash
# Main checker - does all logic, returns block/allow
# Reads JSON from stdin, returns exit 0 = allow, exit 1 = deny

set -euo pipefail

# Read input JSON from stdin
INPUT=$(cat)

TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")
FILE_PATH=$(jq -r '.tool_input.file_path // empty' <<< "$INPUT")
CONTENT=$(jq -r '.tool_input.content // empty' <<< "$INPUT")

# Only check Write operations
if [[ "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

# Validate inputs
if [[ -z "$FILE_PATH" || -z "$CONTENT" ]]; then
    echo "Missing path or content"
    exit 1
fi

# Path validation - block path traversal
case "$FILE_PATH" in
    *../*|*/../*|../*|~*) echo "Path traversal not allowed"; exit 1;;
esac

if [[ "$FILE_PATH" =~ [\$\`\"\'\;\|] ]]; then
    echo "Invalid characters in path"
    exit 1
fi

# Skip hook system files
case "$FILE_PATH" in
    hooks/*|tools/*|checkers/*|rules/*|.claude/*) exit 0;;
esac

# Get extension
EXT="${FILE_PATH##*.}"
[[ "$EXT" == "$FILE_PATH" ]] && EXT=""

# No extension = allow
[[ -z "$EXT" ]] && exit 0

# Get repo dir
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKERS_DIR="$REPO_DIR/checkers"
CHECKER="$CHECKERS_DIR/$EXT.sh"

# No checker = allow (fail-open)
if [[ ! -x "$CHECKER" ]]; then
    exit 0
fi

# Create temp file for checker
TMP_DIR=$(mktemp -d) || { echo "Failed to create temp dir"; exit 1; }
trap 'rm -rf "$TMP_DIR"' EXIT

# Sanitize filename - use basename to prevent path traversal
BASENAME=$(basename "$FILE_PATH")
TMP_FILE="$TMP_DIR/$BASENAME"
printf '%s' "$CONTENT" > "$TMP_FILE"

# Run checker - exit 0 = pass, exit 1+ = fail
if "$CHECKER" "$TMP_FILE" 2>/dev/null; then
    exit 0
else
    # Checker failed - get reason
    REASON=$("$CHECKER" "$TMP_FILE" 2>&1 | head -1) || true
    [[ -z "$REASON" ]] && REASON="Check failed"
    echo "$REASON"
    exit 1
fi
