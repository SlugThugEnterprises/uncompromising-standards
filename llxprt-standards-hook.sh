#!/bin/bash
# =============================================================================
# LLxprt Standards Adapter - Final Version
# 
# Bridges LLxprt BeforeTool hooks with uncompromising-standards checker
# Same strict Rust rules as Claude Code
# =============================================================================

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${YELLOW}[LLxprt-Hook]${NC} $1" >&2
}

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .tool // "unknown"')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .path // ""')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .content // ""')

log "Intercepted: $TOOL_NAME -> $FILE_PATH"

if [[ "$TOOL_NAME" != *"write_file"* ]] && [[ "$TOOL_NAME" != *"Write"* ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

if [[ -z "$FILE_PATH" ]] || [[ -z "$CONTENT" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

log "Running uncompromising standards check..."

CHECKER_OUTPUT=$(/opt/uncompromising-standards/tools/check.sh << EOF
{
  "tool_name": "write_file",
  "tool_input": {
    "file_path": "$FILE_PATH",
    "content": $(echo "$CONTENT" | jq -Rs .)
  }
}
EOF
2>&1)
CHECKER_EXIT=$?

if [[ $CHECKER_EXIT -eq 0 ]]; then
    log "${GREEN}Standards check PASSED [OK]${NC}"
    echo '{"decision": "allow"}'
    exit 0
else
    REASON=$(echo "$CHECKER_OUTPUT" | head -3 | tr '\n' ' ' | sed 's/"/\\"/g')
    log "${RED}BLOCKED: $REASON${NC}"
    echo "{\"decision\": \"deny\", \"reason\": \"Uncompromising Standards violation: $REASON\"}"
    exit 2
fi
