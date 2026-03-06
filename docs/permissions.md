# Permissions

Control what tools Claude Code can use.

## Deny Files

Block access to sensitive files:

```json
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./secrets/**)",
      "Write(./prod-config.json)"
    ]
  }
}
```

## Allow Tools

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Write(./src/**)",
      "Edit(*.rs)"
    ]
  }
}
```

## Tool Patterns

| Pattern | Matches |
|---------|---------|
| `Bash` | Any bash command |
| `Bash(npm test)` | Only `npm test` |
| `Bash(npm run *)` | Any `npm run` command |
| `Read(./src/**)` | Any file in src |
| `Write(*.log)` | Any log file |

## Run /allowed-tools

Use `/allowed-tools` to see current permissions interactively.
