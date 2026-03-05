#!/bin/bash
# Pre-Write Hook - delegates to checker
# Exit 0 = allow, Exit 2 = deny

allow() { echo '{"decision":"allow"}'; exit 0; }
deny()  { echo "{\"decision\":\"deny\",\"reason\":\"$1\"}" >&2; exit 2; }

# Test mode
[[ "${1:-}" == "--test" ]] && { echo "/quit"; exit 0; }

INPUT=$(cat)

# Get checker path relative to this script
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$HOOK_DIR/.." && pwd)"
CHECKER="$REPO_DIR/tools/checker.sh"

# Call checker - exit 0 = allow, exit 1 = deny
if "$CHECKER" <<< "$INPUT" 2>&1; then
    allow
else
    # Checker returned reason on stdout
    REASON=$("$CHECKER" <<< "$INPUT" 2>&1 | head -1) || true
    [[ -z "$REASON" ]] && REASON="Check failed"
    deny "$REASON"
fi
