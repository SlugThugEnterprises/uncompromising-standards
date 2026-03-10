# Bash Rules Reference

When triggered, error format:
```
[SEVERITY] - [RULE_NAME] - Line [NUMBER]
```

## CRITICAL (blocks write)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| Missing `set -e` | - | Error handling not enabled | Add `set -e` at top |
| TODO/FIXME | # | Placeholder comments | Implement or remove |
| Unquoted vars | # | Variables without quotes | Use `"$VAR"` |
| Unsafe `rm` | # | `rm -rf` recursive flags | Use safer alternatives |
| Catastrophic `rm` | # | `rm -rf /` or `rm -rf .` | Never do this |
| `eval` usage | # | Security risk | Avoid `eval` |
| Secrets | # | Hardcoded passwords/keys | Use env vars |

## WARNING (informational)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| Missing `set -u` | - | No unbound var detection | Add `set -u` |
| Missing `set -o pipefail` | - | No pipeline error handling | Add `set -o pipefail` |
| Backticks | # | Deprecated `\`...\`` | Use `$(...)` |
| `set -x` | # | Debug mode in production | Remove before commit |

## Exceptions

```bash
# standards-disable: some-rule
```
