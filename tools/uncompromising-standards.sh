#!/bin/bash
# Uncompromising Standards Checker
# Orchestrates static code analysis for various file types

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source config
source "$REPO_DIR/base-rules/lib/config.sh"

usage() {
    echo "Usage: $0 --file <file> [--stdin]"
    echo "  --file <file>   Path to file to check"
    echo "  --stdin         Read content from stdin"
    exit 1
}

# Parse arguments
FILE=""
STDIN_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)
            FILE="$2"
            shift 2
            ;;
        --stdin)
            STDIN_MODE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            shift
            ;;
    esac
done

# Get file info
if [[ "$STDIN_MODE" == "true" ]]; then
    CONTENT=$(cat)
elif [[ -z "$FILE" ]]; then
    usage
elif [[ ! -f "$FILE" ]]; then
    echo "File not found: $FILE"
    exit 1
fi

[[ -n "$FILE" ]] && EXT="${FILE##*.}" || EXT=""

# Route to appropriate enforcer
case "$EXT" in
    py)
        ENFORCER="$REPO_DIR/base-rules/python-enforcer.py"
        ;;
    rs)
        ENFORCER="$REPO_DIR/base-rules/rust-enforcer.sh"
        ;;
    js|mjs|cjs|ts|mts|cts)
        ENFORCER="$REPO_DIR/base-rules/javascript-enforcer.js"
        ;;
    rb)
        ENFORCER="$REPO_DIR/base-rules/ruby-enforcer.rb"
        ;;
    go)
        ENFORCER="$REPO_DIR/base-rules/go-enforcer.sh"
        ;;
    sh|bash)
        ENFORCER="$REPO_DIR/base-rules/bash-enforcer.sh"
        ;;
    sql)
        ENFORCER="$REPO_DIR/base-rules/sql-enforcer.sh"
        ;;
    md|mdx)
        ENFORCER="$REPO_DIR/base-rules/markdown-enforcer.sh"
        ;;
    *)
        # Unknown extension - pass
        exit 0
        ;;
esac

# Run enforcer
if [[ -x "$ENFORCER" ]]; then
    if [[ -n "$FILE" && -f "$FILE" ]]; then
        exec "$ENFORCER" "$FILE"
    elif [[ "$STDIN_MODE" == "true" && -n "$CONTENT" ]]; then
        echo "$CONTENT" | exec "$ENFORCER" -
    fi
fi

# No enforcer - pass
exit 0
