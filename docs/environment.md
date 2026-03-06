# Environment Variables

## Key Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | API key for Claude |
| `ANTHROPIC_MODEL` | Model to use |
| `CLAUDE_CONFIG_DIR` | Config directory path |
| `CLAUDE_CODE_SIMPLE` | Minimal mode (1 = on) |
| `DISABLE_TELEMETRY` | Disable statsig telemetry (1 = on) |
| `DISABLE_AUTOUPDATER` | Disable auto-update (1 = on) |
| `HTTP_PROXY` / `HTTPS_PROXY` | Proxy server |
| `MAX_THINKING_TOKENS` | Extended thinking budget |
| `BASH_MAX_TIMEOUT_MS` | Max bash timeout |

## Making Vars Persistent

### Option 1: Before starting Claude

```bash
export MY_VAR=value
claude
```

### Option 2: CLAUDE_ENV_FILE

```bash
export CLAUDE_ENV_FILE=/path/to/env.sh
claude
```

Where `env.sh` contains your exports.

### Option 3: SessionStart hook

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup",
      "hooks": [{
        "type": "command",
        "command": "echo 'export VAR=value' >> $CLAUDE_ENV_FILE"
      }]
    }]
  }
}
```
