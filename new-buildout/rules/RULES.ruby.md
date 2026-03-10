# Ruby Rules Reference

When triggered, error format:
```
[SEVERITY] - [RULE_NAME] - Line [NUMBER]
```

## CRITICAL (blocks write)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| `file-length` | - | File exceeds 200 lines | Split into modules |
| `function-length` | - | Function exceeds 50 lines | Refactor |
| `binding.pry` / `byebug` | # | Debugger statements | Remove |
| `puts` | # | Print outside tests | Use logger |
| `todo` | # | TODO/FIXME comments | Implement or remove |
| Secrets | # | Hardcoded credentials | Use env vars |

## Exceptions

```ruby
# rubocop:disable SomeRule
# standards-disable: some-rule
```
