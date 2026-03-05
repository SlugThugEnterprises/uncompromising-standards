#!/bin/bash
# Main checker - routes to language-specific checkers dynamically
# Exit 0 = pass, Exit 1+ = fail

EXT="$1"
FILE="$2"

# Get script dir (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || { echo "No checker available for extension, blocking by default" >&2; exit 1; }
CHECKERS_DIR="$SCRIPT_DIR/checkers"

# No extension = allow
[[ -z "$EXT" ]] && exit 0

# Check if checker exists for this extension
CHECKER="$CHECKERS_DIR/$EXT.sh"

if [[ -x "$CHECKER" ]]; then
    # Run the checker
    exec "$CHECKER" "$FILE"
else
    # No checker for this extension = allow (fail-open)
    exit 0
fi
