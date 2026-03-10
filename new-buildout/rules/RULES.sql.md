# SQL Rules Reference

When triggered, error format:
```
[SEVERITY] - [RULE_NAME] - Line [NUMBER]
```

## CRITICAL (blocks write)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| `file-length` | - | File exceeds 200 lines | Split into multiple files |
| `DROP DATABASE` | # | Dangerous drop statement | Avoid in production |
| Secrets | # | Passwords in SQL | Use env vars |

## Exceptions

```sql
-- standards-disable: some-rule
```
