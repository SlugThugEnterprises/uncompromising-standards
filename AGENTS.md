# AGENTS.md - Uncompromising Standards

> "Code so good you could trust it with your friend's mom's life."

This is a **code quality enforcement plugin** for Claude Code with mandatory enforcement.

## Project Structure

```
uncompromising-standards/
├── checkers/           # Language-specific validators (rs.sh, py.sh, sh.sh)
├── rules/              # Language-specific rules (RULES.*.md)
├── tools/              # check.sh, format-error.sh, verify-hook.sh
└── new-buildout/       # Development version with tests/
```

## Build/Lint/Test Commands

### Running Individual Checkers

```bash
./checkers/rs.sh path/to/file.rs  # Rust (100 line max)
./checkers/py.sh path/to/file.py  # Python (300 line max)
./checkers/sh.sh path/to/file.sh  # Bash
```

### Test Suite

```bash
./new-buildout/tests/run_tests.sh
./tools/verify-hook.sh
```

## Universal Code Standards

These rules apply to **ALL** languages:

### Forbidden Patterns (Always Critical)
- ❌ `TODO`, `FIXME`, `HACK`, `XXX`, `TEMP`, `WIP`, `PLACEHOLDER` comments
- ❌ `eval()`, `exec()` - dynamic code execution (security risk)
- ❌ Wildcard imports: `import *`, `require(*)`
- ❌ Hardcoded secrets (API keys, passwords, tokens)
- ❌ Debugger statements: `breakpoint()`, `pdb`, `debugger`

### Size Limits
| Language | File Limit | Function Limit |
|----------|-----------|----------------|
| Rust     | 100 lines | 50 lines       |
| Python   | 300 lines | 50 lines       |
| Bash     | 200 lines | 50 lines       |
| Go       | 200 lines | 50 lines       |
| JS/TS    | 200 lines | 50 lines       |

### Naming Conventions
- ❌ **No single-letter variables** (except `i`, `j`, `k` for loops, `x`, `y`, `z` for math)

## Language-Specific Rules

### Rust

**Required at crate root:**
```rust
#![forbid(unsafe_code)]
```

**Forbidden patterns:**
| Pattern | Use Instead |
|---------|-------------|
| `unwrap()`, `expect()`, `panic!()` | `?` operator or `match` |
| `array[i]` | `array.get(i)` |
| `a + b` | `a.saturating_add(b)` |
| `vec![1,2]` | `[1, 2]` (stack array) |
| `Box`, `Arc`, `Rc`, `HashMap` | stack-allocated types |
| `println!`, `dbg!()` | proper logging |
| `todo!`, `TODO` | implement or remove |

**Test files**: Use `_test.rs` suffix or `tests/` directory. `unwrap()` allowed in tests.

### Python

**Required on public functions:**
```python
def process(data: str) -> dict:  # type hints required
    ...
```

**Forbidden patterns:**
| Pattern | How to Fix |
|---------|------------|
| `except:` | `except SpecificError:` |
| `except: pass` | handle exception properly |
| `print()` in logic | use `logging` module |
| `Any` type | use specific types |
| `data`, `thing`, `stuff`, `obj`, `temp` | descriptive names |
| >5 parameters | use dataclass or split |
| 3+ nested loops | extract to function |

**Quality tools:**
```bash
ruff format --check .  # format check
ruff check .           # lint check
pytest                 # tests
```

### JavaScript/TypeScript

**Forbidden:**
- `console.log()`, `console.debug()`, `console.info()`, `console.warn()`, `console.error()`
- `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`
- `any` type (use `unknown`)
- `debugger` statement
- `eval()`
- `import * as X`

### Bash

**Required at top of every script:**
```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Forbidden:**
- Unquoted variables: `$var` → `"${var}"`
- `rm -rf` without safeguards
- `rm -rf /` or `rm -rf .` (catastrophic)
- `eval` (security risk)
- Backticks: `` `cmd` `` → `$(cmd)`
- `set -x` in production

## Error Handling

### Rust
```rust
// Good - propagate errors
fn parse(data: &str) -> Result<Config, ParseError> {
    let cfg = serde_json::from_str(data)?;
    Ok(cfg)
}

// Bad - panics
fn parse(data: &str) -> Config {
    serde_json::from_str(data).unwrap()
}
```

### Python
```python
# Good
try:
    result = client.lookup(address)
except TimeoutError as exc:
    raise AddressLookupError("Lookup timed out") from exc

# Bad
try:
    result = client.lookup(address)
except:
    pass
```

## Exceptions

Add comments to disable specific rules:

```python
# standards-disable: function-length, file-length
# noqa: some-rule
```

```javascript
// standards-disable: console_log, function_length
```

```bash
# standards-disable: some-rule
```

## Code Style Notes

- Use **shell shebang**: `#!/usr/bin/env bash`
- **Color output** in scripts: `RED`, `GREEN`, `YELLOW`, `NC` ANSI codes
- **Exit codes**: 0 = allow, 1 = error, 2 = block
- **Quotes**: Always quote variables: `"${var}"` or `"${var:-default}"`
- **Globals**: Use uppercase names: `EXIT_CODE`, `$CRITICAL`

## Architecture

```
hooks/pre-write.sh → tools/check.sh → checkers/{rs,py,sh}.sh
```

- **hooks/pre-write.sh**: Minimal trigger, parses JSON, delegates to check.sh
- **tools/check.sh**: Main logic - extracts content, runs appropriate checker
- **checkers/**: Language-specific validators
  - `rs.sh` - Rust (18 checks)
  - `py.sh` - Python (custom + ruff)
  - `sh.sh` - Bash

## Enforcement Mode

This plugin operates in **mandatory enforcement mode**. AI agents MUST pass all standards before code is written. The code either meets standards or it doesn't get written.

## OpenCode Integration

OpenCode uses the [froggy plugin](https://github.com/smartfrog/opencode-froggy) for hooks.

### Installation

1. Add to `opencode.json`:
```json
{
  "plugin": ["opencode-froggy"]
}
```

2. Copy hook config:
```bash
mkdir -p ~/.config/opencode/hook
cp integrations/opencode/hooks.md ~/.config/opencode/hook/hooks.md
```

### How It Works

The froggy plugin intercepts `tool.before.write` and `tool.before.edit` events, runs the shell checkers, and **exit code 2 blocks the tool**.
