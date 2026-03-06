# Hooks

Hooks let you run custom commands before/after tools execute.

## Hook Types

- **PreToolUse**: Runs before a tool executes
- **PostToolUse**: Runs after a tool completes
- **PostToolUseFailure**: Runs when tool fails
- **Notification**: Runs on specific events
- **Stop**: Runs when Claude Code stops
- **SessionStart**: Runs when session starts

## Configuration

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write",
      "hooks": [{
        "type": "command",
        "command": "./check-syntax.sh"
      }]
    }]
  }
}
```

## Matcher Patterns

| Matcher | Matches |
|---------|---------|
| `Write` | Write tool |
| `Bash` | Bash tool |
| `Edit\|Write` | Edit or Write |
| `mcp__.*` | Any MCP tool |

## Input/Output

**Input (JSON from stdin):**
```json
{"tool_name": "Write", "tool_input": {"file_path": "/path/file.rs", "content": "..."}}
```

**Output (JSON to stdout):**

### Allow
```json
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}
```

### Deny/Block
```json
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "TODO markers forbidden"}}
```

## Exit Codes (Legacy)

- `0` = Allow (or use `permissionDecision: "allow"`)
- `1` = Block with warning
- `2` = Block with error (or use `permissionDecision: "deny"`)

## Example: Pre-write Check

```bash
#!/bin/bash
# .claude/hooks/pre-write.sh

read input
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Check file
if grep -q "TODO" "$file_path"; then
  echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "TODO markers forbidden"}}'
  exit 2
fi

exit 0
```

## Settings

```json
{
  "allowedHttpHookUrls": ["https://hooks.example.com/*"],
  "httpHookAllowedEnvVars": ["MY_TOKEN"]
}
```
