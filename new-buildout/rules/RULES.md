# Base Rules (All Languages)

These principles apply to all languages.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **DRY** | Don't Repeat Yourself - extract common logic |
| **KISS** | Keep It Simple, Stupid - simple > clever |
| **YAGNI** | You Aren't Gonna Need It - don't add features speculatively |
| **SOLID** | Single responsibility, Open-closed, Liskov substitution, Interface segregation, Dependency inversion |

## Universal CRITICAL Rules

| Rule | What | How to Fix |
|------|------|------------|
| File length | File exceeds 200 lines | Split into modules |
| Function length | Function exceeds 50 lines | Refactor |
| TODO/FIXME/HACK | Placeholder comments | Implement or remove |
| Secrets | Hardcoded API keys, passwords, tokens | Use env vars or secrets manager |
| Debugger statements | `breakpoint()`, `pdb`, debugger | Remove before commit |

## Universal ERROR Rules

| Rule | What | How to Fix |
|------|------|------------|
| `eval()` / `exec()` | Dynamic code execution | Avoid - security risk |
| Wildcard imports | `import *`, `require(*)` | Import specific names |

## Per-Language Rules

See language-specific rules:
- `RULES.python.md`
- `RULES.javascript.md`
- `RULES.bash.md`
- `RULES.go.md`
- `RULES.rust.md`
- `RULES.ruby.md`
- `RULES.sql.md`
- `RULES.markdown.md`

## Universal Exceptions

Most rules can be disabled with:
```python
# standards-disable: rule-name
# noqa: rule-name
```
