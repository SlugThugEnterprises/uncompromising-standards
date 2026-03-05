#!/bin/bash
set -euo pipefail

# Uncompromising Standards Installer
# Installs hooks into Claude Code and/or LLxprt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_SCRIPT="$REPO_DIR/hooks/pre-write.sh"

echo "Uncompromising Standards Installer"
echo "===================================="
echo ""

# Check if hook script exists
if [[ ! -f "$HOOK_SCRIPT" ]]; then
    echo "Error: Hook script not found at $HOOK_SCRIPT"
    exit 1
fi

chmod +x "$HOOK_SCRIPT"
echo "Hook script: $HOOK_SCRIPT"
echo ""

detect_claude() {
    [[ -f "$HOME/.claude/settings.json" ]] && echo "$HOME/.claude/settings.json"
}

detect_llxprt() {
    [[ -f "$HOME/.llxprt/settings.json" ]] && echo "$HOME/.llxprt/settings.json"
}

install_claude_hook() {
    local settings_file="$1"
    local temp_file="$settings_file.tmp"

    echo "Installing Claude Code hook..."

    # FIX F003: Validate JSON before manipulation
    if ! jq -e '.' "$settings_file" > /dev/null 2>&1; then
        echo "Error: Invalid JSON in $settings_file"
        exit 1
    fi

    if jq -e '.hooks.PreToolUse' "$settings_file" &> /dev/null; then
        if jq --arg cmd "$HOOK_SCRIPT" '.hooks.PreToolUse | any(.hooks[]?.command == $cmd)' "$settings_file" | grep -q "true"; then
            echo "  Hook already installed"
            return
        fi
        jq --arg cmd "$HOOK_SCRIPT" '.hooks.PreToolUse += [{"matcher": "Write", "hooks": [{"type": "command", "command": $cmd}]}]' "$settings_file" > "$temp_file" && mv "$temp_file" "$settings_file"
    else
        jq --arg cmd "$HOOK_SCRIPT" '.hooks.PreToolUse = [{"matcher": "Write", "hooks": [{"type": "command", "command": $cmd}]}]' "$settings_file" > "$temp_file" && mv "$temp_file" "$settings_file"
    fi
    echo "  Added PreToolUse hook"
}

install_llxprt_hook() {
    local settings_file="$1"
    local temp_file="$settings_file.tmp"

    echo "Installing LLxprt hook..."

    # FIX F003: Validate JSON before manipulation
    if ! jq -e '.' "$settings_file" > /dev/null 2>&1; then
        echo "Error: Invalid JSON in $settings_file"
        exit 1
    fi

    if jq -e '.hooks.BeforeTool' "$settings_file" &> /dev/null; then
        if jq --arg cmd "$HOOK_SCRIPT" '.hooks.BeforeTool | any(.hooks[]?.command == $cmd)' "$settings_file" | grep -q "true"; then
            echo "  Hook already installed"
            return
        fi
        jq --arg cmd "$HOOK_SCRIPT" '.hooks.BeforeTool += [{"hooks": [{"type": "command", "command": $cmd}]}]' "$settings_file" > "$temp_file" && mv "$temp_file" "$settings_file"
    else
        jq --arg cmd "$HOOK_SCRIPT" '.hooks.BeforeTool = [{"hooks": [{"type": "command", "command": $cmd}]}]' "$settings_file" > "$temp_file" && mv "$temp_file" "$settings_file"
    fi

    # Enable hooks
    if ! jq -e '.enableHooks' "$settings_file" &> /dev/null; then
        jq '.enableHooks = true' "$settings_file" > "$temp_file" && mv "$temp_file" "$settings_file"
    fi
    echo "  Added BeforeTool hook"
}

uninstall() {
    echo "Uninstalling..."
    for settings_file in "$(detect_claude)" "$(detect_llxprt)"; do
        [[ -z "$settings_file" ]] && continue
        temp_file="$settings_file.tmp"
        if jq --arg script "pre-write.sh" '.hooks.PreToolUse = [.hooks.PreToolUse[] | select(.hooks[]?.command | contains($script) | not)]' "$settings_file" > "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$settings_file"
        fi
        if jq --arg script "pre-write.sh" '.hooks.BeforeTool = [.hooks.BeforeTool[] | select(.hooks[]?.command | contains($script) | not)]' "$settings_file" > "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$settings_file"
        fi
    done
    echo "Done"
}

case "${1:-install}" in
    install)
        claude_settings=$(detect_claude)
        llxprt_settings=$(detect_llxprt)

        [[ -n "$claude_settings" ]] && echo "Claude Code: Found"
        [[ -n "$llxprt_settings" ]] && echo "LLxprt: Found"

        [[ -z "$claude_settings" && -z "$llxprt_settings" ]] && echo "Error: No settings found" && exit 1

        [[ -n "$claude_settings" ]] && install_claude_hook "$claude_settings"
        [[ -n "$llxprt_settings" ]] && install_llxprt_hook "$llxprt_settings"

        echo ""
        echo "Installation complete!"
        echo "Hook: $HOOK_SCRIPT"
        ;;
    uninstall)
        uninstall
        ;;
esac
