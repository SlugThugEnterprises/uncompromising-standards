#!/usr/bin/env bash
# =============================================================================
# Hook Verification Script
#
# Tests whether the pre-write hook is correctly configured in Claude Code.
# Does NOT test the checker logic itself - just whether the hook would fire.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_SCRIPT="$PROJECT_ROOT/hooks/pre-write.sh"
CHECK_SCRIPT="$PROJECT_ROOT/tools/check.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

errors=0
warnings=0

echo "Uncompromising Standards - Hook Verification"
echo "============================================"
echo ""

# Test 1: Check if hook script exists
echo -n "1. Hook script exists... "
if [[ -f "$HOOK_SCRIPT" ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} - $HOOK_SCRIPT not found"
    ((errors++))
fi

# Test 2: Check if hook script is executable
echo -n "2. Hook script is executable... "
if [[ -x "$HOOK_SCRIPT" ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} - run: chmod +x $HOOK_SCRIPT"
    ((errors++))
fi

# Test 3: Check if check.sh exists
echo -n "3. Check script exists... "
if [[ -f "$CHECK_SCRIPT" ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} - $CHECK_SCRIPT not found"
    ((errors++))
fi

# Test 4: Check if check.sh is executable
echo -n "4. Check script is executable... "
if [[ -x "$CHECK_SCRIPT" ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} - run: chmod +x $CHECK_SCRIPT"
    ((errors++))
fi

# Test 5: Check if hook is registered in Claude Code settings
echo -n "5. Hook registered in settings.json... "
SETTINGS_FILE="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS_FILE" ]]; then
    # Check if our hook command is in the settings
    if grep -q "pre-write.sh" "$SETTINGS_FILE" 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC} - hook not found in settings.json"
        echo "   Run ./install.sh_Ignore to install"
        ((errors++))
    fi
else
    echo -e "${YELLOW}WARN${NC} - $SETTINGS_FILE not found"
    echo "   Run ./install.sh_Ignore to create it"
    ((warnings++))
fi

# Test 6: Check if PreToolUse hook is configured for Write
echo -n "6. PreToolUse hook configured for Write... "
if [[ -f "$SETTINGS_FILE" ]] && command -v jq &>/dev/null; then
    if jq -e '.hooks.PreToolUse[] | select(.matcher == "Write")' "$SETTINGS_FILE" &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC} - no PreToolUse hook for Write"
        ((errors++))
    fi
else
    echo -e "${YELLOW}SKIP${NC} - settings.json or jq not available"
    ((warnings++))
fi

# Test 7: Smoke test - can the hook be invoked?
echo -n "7. Hook can be invoked (smoke test)... "
# Use a minimal valid Rust file that passes all checks
test_content='#![forbid(unsafe_code)]
fn main() {}
'
test_payload=$(jq -n \
    --arg content "$test_content" \
    '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/test.rs", "content": $content}}')

if output=$($HOOK_SCRIPT <<< "$test_payload" 2>&1); then
    echo -e "${GREEN}PASS${NC}"
else
    exit_code=$?
    if [[ $exit_code -eq 2 ]]; then
        # Exit 2 means the hook ran but blocked (which is fine for this test)
        echo -e "${GREEN}PASS${NC} (blocked as expected)"
    else
        echo -e "${RED}FAIL${NC} - exit code: $exit_code"
        echo "   Output: $output"
        ((errors++))
    fi
fi

echo ""
echo "============================================"
echo "Results: $errors error(s), $warnings warning(s)"
echo ""

if [[ $errors -eq 0 ]]; then
    echo -e "${GREEN}Hook is correctly configured!${NC}"
    exit 0
else
    echo -e "${RED}Hook verification failed.${NC} Fix the errors above."
    exit 1
fi
