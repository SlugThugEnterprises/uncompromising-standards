#!/bin/bash
# Pre-Write Hook - thin router
# Just catches the write, delegates all logic to tools/checker.sh

set -euo pipefail

allow() { echo '{"decision":"allow"}'; exit 0; }
deny()  { echo "{\"decision\":\"deny\",\"reason\":\"$1\"}" >&2; exit 2; }

# Test mode
[[ "${1:-}" == "--test" ]] && { echo "/quit"; exit 0; }

INPUT=$(cat)

TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")
[[ "$TOOL_NAME" != "Write" ]] && allow

FILE_PATH=$(jq -r '.tool_input.file_path // empty' <<< "$INPUT")
CONTENT=$(jq -r '.tool_input.content // empty' <<< "$INPUT")
[[ -z "$FILE_PATH" || -z "$CONTENT" ]] && deny "Missing path or content"

# Sanitize path - prevent command injection
if [[ "$FILE_PATH" =~ [\$\`\"\'\;\|] ]]; then
    deny "invalid characters in path"
fi

# Prevent directory traversal
case "$FILE_PATH" in
    *../*|*/../*|../*) deny "path traversal not allowed";;
esac

# Get repo dir
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Skip hook system files - allow writes to hooks/, tools/, checkers/, rules/
case "$FILE_PATH" in
    hooks/*|tools/*|checkers/lib/*|rules/*|.claude/*) allow ;;
esac

# Get extension
EXT="${FILE_PATH##*.}"
[[ "$EXT" == "$FILE_PATH" ]] && EXT=""

CHECKER="$REPO_DIR/tools/checker.sh"

# No extension = allow
[[ -z "$EXT" ]] && allow

# Checker not found = allow (fail-open for unknown languages)
[[ ! -x "$CHECKER" ]] && allow

# Create temp file
TMP_DIR=$(mktemp -d) || deny "temp failed"
trap 'rm -rf "$TMP_DIR"' EXIT

TMP_FILE="$TMP_DIR/$FILE_PATH"
mkdir -p "$(dirname "$TMP_FILE")"
printf '%s' "$CONTENT" > "$TMP_FILE"

# Call checker - exit 0 = allow, exit 1+ = deny
CHECKER_OUTPUT=$("$CHECKER" "$EXT" "$TMP_FILE" 2>&1) || {
    # Pass through the checker output as the error message
    ERROR_MSG=$(echo "$CHECKER_OUTPUT" | head -5 | tr '\n' ' ' | cut -c1-300)
    deny "$ERROR_MSG"
}

# Checker passed
allow
