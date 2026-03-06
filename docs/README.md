# Claude Code Documentation

Quick reference for Claude Code configuration.

## Topics

- [Hooks](hooks.md) - Run code before/after tools
- [Settings](settings.md) - Configuration precedence
- [Skills](skills.md) - Custom prompts with /skill-name
- [MCP](mcp.md) - Model Context Protocol servers
- [Permissions](permissions.md) - Tool access control
- [Environment](environment.md) - Environment variables
- [Subagents](subagents.md) - Custom AI agents

## Quick Start

```json
// .claude/settings.json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write",
      "hooks": [{ "type": "command", "command": "./hooks/pre-write.sh" }]
    }]
  }
}
```

## File Structure

```
.claude/
├── settings.json      # Project settings
├── settings.local.json # Local overrides
├── hooks/             # Hook scripts
├── skills/            # Custom skills
├── agents/            # Subagents
└── Coding-standards   # Your coding rules
```
