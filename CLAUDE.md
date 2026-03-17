# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **uncompromising-standards** project - a Claude Code pre-write hook that enforces strict code quality standards. When enabled, it intercepts Write operations and validates the code against language-specific rules before allowing the write.

## Architecture

```
hooks/pre-write.sh → tools/check.sh → checkers/{rs,py,sh}.sh
```

- **hooks/pre-write.sh**: Minimal trigger that reads JSON from Claude Code and delegates to check.sh
- **tools/check.sh**: Main logic - parses JSON, extracts content, runs appropriate checker
- **checkers/**: Language-specific validators
  - `rs.sh` - Rust (18 checks)
  - `py.sh` - Python (custom + ruff)
  - `sh.sh` - Bash

## Commands

```bash
# Run the test suite
./new-buildout/tests/run_tests.sh

# Verify hook is configured correctly
./tools/verify-hook.sh

# Test a file directly with a checker
./checkers/rs.sh /path/to/file.rs
./checkers/py.sh /path/to/file.py
./checkers/sh.sh /path/to/file.sh
```

## Configuration

The hook is configured in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write",
      "hooks": [{ "type": "command", "command": "/opt/uncompromising-standards/hooks/pre-write.sh" }]
    }]
  }
}
```

## Exit Codes

- **0** = Allow (check passed)
- **1** = Checker error or fail
- **2** = Block (check failed)

## Rules Files

Language-specific rules are in `rules/RULES.<lang>.md`:
- `RULES.rust.md` - Max 100 lines, no unsafe, no unwrap, saturating math only
- `RULES.python.md` - Max 150 lines, type hints required, no print()
- `RULES.bash.md` - Requires set -euo pipefail

## Environment Variables

- `DISABLE_SETUP=1` - Skip automatic creation of `.claude/Coding-standards` file in user projects

## Development

The `new-buildout/` directory contains the development version. Test changes there first before syncing to production.

## Supported File Types

The hook auto-detects by extension: `.rs` → Rust, `.py` → Python, `.sh`/`.bash` → Bash. Unknown file types pass through without checking.
