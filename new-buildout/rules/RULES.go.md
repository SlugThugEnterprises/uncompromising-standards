# Go Rules Reference

When triggered, error format:
```
[SEVERITY] - [RULE_NAME] - Line [NUMBER]
```

## CRITICAL (blocks write)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| `file-length` | - | File exceeds 200 lines | Split into modules |
| `function-length` | - | Function exceeds 50 lines | Refactor |
| `panic` | # | `panic()` calls | Return errors instead |
| `todo` | # | TODO/FIXME/HACK/XXX comments | Remove |
| `nil_deref` | # | Potential nil pointer | Add nil checks |
| Secrets | # | Hardcoded credentials | Use env vars |

## ERROR (blocks write)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| `fmt_print` | # | `fmt.Print*/fmt.Printf` outside main/tests | Use `log`, `zap`, or `zerolog` |
| `err_ignore` | # | Ignored error returns | Handle or explicitly ignore with `_` |

## Exceptions

```go
//go:build ignore
// standards-disable: some-rule
```
