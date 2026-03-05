#!/bin/bash
set -euo pipefail

# Uncompromising Standards - Installer
# Installs pre-write hooks to Claude Code for static code analysis

echo "Uncompromising Standards Installer"
echo "===================================="
echo ""

# Check dependencies
for cmd in jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is required but not installed"
        exit 1
    fi
done

# Find installation directory (where this script is located)
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installation directory: $INSTALL_DIR"
echo ""

# Make scripts executable
echo "Making scripts executable..."
chmod +x "$INSTALL_DIR/checker"
chmod +x "$INSTALL_DIR/hooks/pre-write.sh"
chmod +x "$INSTALL_DIR/base-rules/python-enforcer.py"
chmod +x "$INSTALL_DIR/base-rules/javascript-enforcer.js"
echo "  - checker"
echo "  - hooks/pre-write.sh"
echo "  - base-rules/python-enforcer.py"
echo "  - base-rules/javascript-enforcer.js"
echo ""

# Determine hook command path
HOOK_SCRIPT="$INSTALL_DIR/hooks/pre-write.sh"

# Settings file location
SETTINGS_FILE="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

# Build our hook configuration
OUR_HOOK=$(jq -n \
    --arg cmd "$HOOK_SCRIPT" \
    '{
        matcher: "Write",
        hooks: [{
            type: "command",
            command: $cmd
        }]
    }')

if [[ -f "$SETTINGS_FILE" ]]; then
    # Backup existing settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
    echo "Backed up existing settings.json to settings.json.backup"

    # Check if PreToolUse hooks already exist
    if jq -e '.hooks.PreToolUse' "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo "Existing PreToolUse hooks found, appending our hook..."
        # Append our hook to existing PreToolUse array
        jq --argjson hook "$OUR_HOOK" \
            '.hooks.PreToolUse += [$hook]' \
            "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    else
        # No PreToolUse hooks, add them
        if jq -e '.hooks' "$SETTINGS_FILE" > /dev/null 2>&1; then
            # Has hooks section but no PreToolUse
            jq --argjson hook "$OUR_HOOK" \
                '.hooks.PreToolUse = [$hook]' \
                "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        else
            # No hooks section at all
            jq --argjson hook "$OUR_HOOK" \
                '. + {hooks: {PreToolUse: [$hook]}}' \
                "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        fi
    fi
else
    # Create new settings file with our hook
    jq -n --argjson hook "$OUR_HOOK" \
        '{hooks: {PreToolUse: [$hook]}}' \
        > "$SETTINGS_FILE"
fi

echo "Updated settings.json with pre-write hook"
echo ""

echo "===================================="
echo "Installation complete!"
echo ""
echo "The uncompromising-standards hook will now run"
echo "before every Write operation in Claude Code."
echo ""
echo "It performs static analysis checks:"
echo "  - File length limits (200 lines)"
echo "  - Function length limits (50 lines)"
echo "  - No TODO/FIXME/HACK comments"
echo "  - No hardcoded secrets"
echo "  - No debug statements"
echo ""
echo "IMPORTANT: Restart Claude Code or start a new session"
echo "for the hook to take effect."
echo ""
echo "Run /hooks in Claude Code to verify."
