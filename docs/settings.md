# Settings

Claude Code configuration system.

## Settings Files

| Location | Scope |
|----------|-------|
| `~/.claude/settings.json` | User (global) |
| `.claude/settings.json` | Project (shared) |
| `.claude/settings.local.json` | Local machine only |

## Precedence (Highest to Lowest)

1. **Managed settings** - Server/IT policies (cannot override)
2. **Command line args** - Session overrides
3. **Local project** - Per-machine overrides
4. **Shared project** - Team settings
5. **User settings** - Personal preferences

## Verify Settings

Run `/status` in Claude Code to see active settings and their sources.

## Example settings.json

```json
{
  "permissions": {
    "allow": ["Bash(npm run *)", "Write(./src/**)"],
    "deny": ["Read(./secrets/**)"]
  },
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write",
      "hooks": [{ "type": "command", "command": "./check.sh" }]
    }]
  }
}
```

## Key Settings

- `permissions.allow` - Allowed commands
- `permissions.deny` - Blocked commands
- `hooks` - Hook configurations
- `sandbox.filesystem.allowWrite` - Allowed write paths
