# MCP Servers

Model Context Protocol - extend Claude Code with additional tools.

## Add MCP Server

```bash
/claude mcp add <server-name>
```

## Configuration

In `settings.json`:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@some/package"],
      "env": { "API_KEY": "value" }
    }
  }
}
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `MCP_TIMEOUT` | Server startup timeout (ms) |
| `MCP_TOOL_TIMEOUT` | Tool execution timeout (ms) |
| `MCP_CLIENT_SECRET` | OAuth client secret |
| `ENABLE_TOOL_SEARCH` | Enable MCP tool search |

## Marketplace Sources

- `github` - GitHub repository
- `git` - Any git URL
- `npm` - NPM package
- `url` - HTTP URL
- `file` - Local file path
- `directory` - Local directory
