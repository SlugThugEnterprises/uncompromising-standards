# Python Rules Reference

When triggered, error format:
```
[SEVERITY] - [RULE_NAME] - Line [NUMBER]
```

## CRITICAL (blocks write)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| `file-length` | - | File exceeds 200 lines | Split into modules or add `# standards-disable: file-length` |
| `function-length` | - | Function exceeds 50 lines | Refactor or add `# standards-disable: function-length` |
| `bare_except` | # | Bare `except:` found | Use `except Exception as e:` or specific type |
| `todo` | # | TODO/FIXME/HACK/XXX/TEMP/WIP/PLACEHOLDER | Remove placeholder comments |
| `pass_placeholder` | # | Empty `pass` statement | Implement the function |
| `debug_breakpoint` | # | `breakpoint()`, `pdb.set_trace`, `import pdb` | Remove before committing |
| `secret_*` | # | Hardcoded API key/password/token | Use env vars or secrets manager |

## ERROR (blocks write)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| `print_not_main` | # | `print()` outside `__main__` or tests | Use `logging` module |
| `exec_usage` | # | `exec()` function | Avoid dynamic code |
| `eval_usage` | # | `eval()` function | Avoid dynamic code |
| `import_wildcard` | # | `from X import *` | Import specific names |
| `compare_none` | # | `== None` or `is not None` | Use `is None` (PEP 8) |

## WARNING (informational)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| `single-letter-var` | # | Single-letter variable | Use descriptive names (allowed: i,j,k,x,y,z) |

## Exceptions

```python
# standards-disable: file-length, function-length
# noqa: some-rule
```
