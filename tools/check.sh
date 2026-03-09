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
# Check for coding standards file and create if missing
# =============================================================================

CLAUDE_DIR=".claude"
STANDARDS_FILE="$CLAUDE_DIR/Coding-standards"

setup_coding_standards() {
    # Only check when running in actual project context
    # Skip Claude Code config directories
    if [[ "$PROJECT_ROOT" == *"/tmp"* ]] || \
       [[ "$PROJECT_ROOT" == "/root"* ]] || \
       [[ "$PROJECT_ROOT" == "$HOME/.config"* ]]; then
        return
    fi

    # Create .claude directory if it doesn't exist
    if [[ ! -d "$PROJECT_ROOT/$CLAUDE_DIR" ]]; then
        mkdir -p "$PROJECT_ROOT/$CLAUDE_DIR"
    fi

    # Create coding standards file if it doesn't exist
    if [[ ! -f "$PROJECT_ROOT/$STANDARDS_FILE" ]]; then
        # Determine which rules file to use based on project files
        local rules_file=""

        # Check for project type markers in order of specificity
        if [[ -f "$PROJECT_ROOT/go.mod" ]]; then
            rules_file="$SCRIPT_DIR/../rules/RULES.go.md"
        elif [[ -f "$PROJECT_ROOT/package.json" ]]; then
            rules_file="$SCRIPT_DIR/../rules/RULES.javascript.md"
        elif [[ -f "$PROJECT_ROOT/Pipfile" ]] || [[ -f "$PROJECT_ROOT/requirements.txt" ]]; then
            rules_file="$SCRIPT_DIR/../rules/RULES.python.md"
        elif [[ -f "$PROJECT_ROOT/Cargo.toml" ]]; then
            rules_file="$SCRIPT_DIR/../rules/RULES.rust.md"
        else
            # Default to rust rules (since this hook is primarily for rust)
            rules_file="$SCRIPT_DIR/../rules/RULES.rust.md"
        fi

        # Copy the rules file if it exists
        if [[ -f "$rules_file" ]]; then
            cp "$rules_file" "$PROJECT_ROOT/$STANDARDS_FILE"
        fi
    fi
}

# =============================================================================
# Check if file should be bypassed (hook/tooling files)
# =============================================================================

should_bypass() {
    local file_path="$1"

    # Directories that bypass validation
    local bypass_dirs=("hooks" "tools" "checkers" "rules" ".claude")

    for dir in "${bypass_dirs[@]}"; do
        if [[ "$file_path" == *"/$dir/"* ]] || [[ "$file_path" == *"/$dir" ]] || [[ "$file_path" == "$dir"* ]]; then
            return 0  # bypass
        fi
    done
    return 1  # don't bypass
}

# =============================================================================
# Get checker script for file type
# =============================================================================

get_checker() {
    local file_path="$1"
    local ext="${file_path##*.}"

    case "$ext" in
        rs) echo "$CHECKERS_DIR/rs.sh" ;;
        sh|bash) echo "$CHECKERS_DIR/sh.sh" ;;
        py) echo "$CHECKERS_DIR/py.sh" ;;
        *) echo "" ;;
    esac
}

# =============================================================================
# Main: Parse JSON from Claude Code, run checker, return exit code
# =============================================================================

main() {
    # Setup coding standards file if needed
    setup_coding_standards

    # Read JSON from stdin
    local input
    input=$(cat)

    # Extract tool_name (support both Claude Code and LLxprt formats)
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // .tool // empty')

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

    # Check if file should bypass validation
    if should_bypass "$file_path"; then
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
        # Check failed - format as proper JSON response
        local formatted
        formatted=$(echo "$checker_output" | "$SCRIPT_DIR/format-error.sh")
        if [[ -z "$formatted" ]]; then
            formatted="Code standards check failed"
        fi
        # LLxprt expects deny on stdout
        if [[ "$input" == *'"tool"'* ]]; then
            echo "{\"decision\": \"deny\", \"reason\": \"$formatted\"}"
        fi
        # Claude Code expects deny on stderr
        echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"deny\", \"permissionDecisionReason\": \"$formatted\"}}" >&2
        exit 2
    fi
}

main "$@"
