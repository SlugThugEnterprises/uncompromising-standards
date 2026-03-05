#!/usr/bin/env bash
# =============================================================================
# Code Standards Checker - Claude Code Pre-Write Hook
#
# Receives JSON from Claude Code, checks code against standards,
# returns exit code to allow/block the Write operation.
#
# Exit codes:
#   0 = allow (check passed)
#   2 = block (check failed, stderr contains reason)
# =============================================================================

set -uo pipefail
set +H  # Disable history expansion

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECKERS_DIR="$PROJECT_ROOT/checkers"

# =============================================================================
# Get checker script for file type
# =============================================================================

get_checker() {
    local file_path="$1"
    local ext="${file_path##*.}"

    case "$ext" in
        rs) echo "$CHECKERS_DIR/rs.sh" ;;
        sh|bash) echo "$CHECKERS_DIR/sh.sh" ;;
        *) echo "" ;;
    esac
}

# =============================================================================
# Main: Parse JSON from Claude Code, run checker, return exit code
# =============================================================================

main() {
    # Read JSON from stdin
    local input
    input=$(cat)

    # Extract tool_name
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // empty')

    # Only run on Write operations
    case "$tool_name" in
        Write|WriteFile|write_file) ;;
        *) exit 0 ;;
    esac

    # Extract file path
    local file_path
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')

    if [[ -z "$file_path" ]]; then
        exit 0
    fi

    # Get checker for this file type
    local checker
    checker=$(get_checker "$file_path")

    if [[ -z "$checker" ]] || [[ ! -x "$checker" ]]; then
        # No checker = allow
        exit 0
    fi

    # Extract content
    local content
    content=$(echo "$input" | jq -r '.tool_input.content // empty')

    if [[ -z "$content" ]]; then
        # No content = allow
        exit 0
    fi

    # Fix jq escaping: \! -> !
    content="${content//\\!/!}"

    # Write content to temp file for checking
    local temp_file
    temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT
    printf '%s' "$content" > "$temp_file"

    # Run checker - output goes to stderr, exit code tells us result
    local checker_output
    checker_output=$("$checker" "$temp_file" 2>&1)
    local checker_rc=$?

    if [[ $checker_rc -eq 0 ]]; then
        # Check passed - allow
        exit 0
    else
        # Check failed - format and return concise error message
        local formatted
        formatted=$(echo "$checker_output" | grep -E 'FAIL' | sed 's/.*❌ FAIL.*: //' | sed 's/   File: .*//' | sed 's/\x1b\[[0-9;]*m//g' | head -10 | tr '\n' ', ' | sed 's/,$//')
        if [[ -z "$formatted" ]]; then
            formatted="Code standards check failed"
        fi
        echo "$formatted" >&2
        exit 2
    fi
}

main "$@"
