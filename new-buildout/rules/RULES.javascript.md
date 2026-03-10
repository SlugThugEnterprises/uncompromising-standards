# JavaScript/TypeScript Rules Reference

When triggered, error format:
```
[SEVERITY] - [RULE_NAME] - Line [NUMBER]
```

## CRITICAL (blocks write)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| `file_length` | - | File exceeds 200 lines | Split into multiple files |
| `function_length` | # | Function exceeds 50 lines | Refactor into smaller functions |
| `console_log` | # | `console.log/debug/info/warn/error` | Remove or use logging library |
| `todo` | # | TODO/FIXME/HACK/XXX/TEMP/WIP/PLACEHOLDER | Remove placeholder comments |
| `ts_ignore` | # | `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck` | Fix TypeScript error properly |
| `any_type` | # | Usage of `any` type | Use proper types |
| `debugger_stmt` | # | `debugger` statement | Remove before committing |
| `secret_*` | # | Hardcoded API keys, tokens | Use environment variables |

## ERROR (blocks write)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| `eval_usage` | # | `eval()` function | Avoid dynamic code |
| `with_statement` | # | `with` statement | Rewrite without `with` |
| `import_star` | # | `import * as X` | Import specific names |

## Exceptions

```javascript
// standards-disable: console_log, function_length
// noqa: some-rule
```
