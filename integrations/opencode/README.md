# OpenCode Integration via Froggy Plugin

This integration uses the [opencode-froggy](https://github.com/smartfrog/opencode-froggy) plugin to provide Claude Code-style pre-write hooks for OpenCode.

## Installation

### 1. Add froggy plugin to opencode.json

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-froggy"]
}
```

### 2. Copy hooks.md to your OpenCode config directory

**For global use (all projects):**
```bash
mkdir -p ~/.config/opencode/hook
cp hooks.md ~/.config/opencode/hook/hooks.md
```

**For project-specific use:**
```bash
mkdir -p .opencode/hook
cp hooks.md .opencode/hook/hooks.md
```

## How It Works

The froggy plugin intercepts `tool.before.write` and `tool.before.edit` events. When these events fire:

1. The hook reads the file path and content from stdin JSON
2. Determines the appropriate checker (rs.sh, py.sh, or sh.sh)
3. Writes content to a temp file and runs the checker
4. **Exit code 2 blocks the tool** - the write/edit is denied
5. **Exit code 0 allows** - the write/edit proceeds

## Bypassed Directories

These directories are automatically bypassed:
- `hooks/`, `tools/`, `checkers/`, `rules/`
- `.opencode/`, `integrations/`

## Supported File Types

| Extension | Checker |
|-----------|---------|
| `.rs` | Rust (rs.sh) |
| `.py` | Python (py.sh) |
| `.sh`, `.bash` | Bash (sh.sh) |

## Example

When you try to write a Rust file with `unwrap()`:

```
[BASH HOOK ✗] ...rs.sh...
Exit: 2 | Duration: 45ms

Error: Code standards violation
```

The tool is blocked and you see the error.

## Requirements

- [opencode-froggy](https://github.com/smartfrog/opencode-froggy) plugin installed
- `jq` installed (for JSON parsing)
- Checkers executable at `/opt/uncompromising-standards/checkers/`
