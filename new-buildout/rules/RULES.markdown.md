# Markdown Rules Reference

When triggered, error format:
```
[SEVERITY] - [RULE_NAME] - Line [NUMBER]
```

## CRITICAL (blocks write)

| Rule | Line | What Triggered It | How to Fix |
|------|------|------------------|------------|
| `file-length` | - | File exceeds 200 lines | Split into multiple files |
| `todo` | # | TODO/FIXME comments | Complete or remove |

## Exceptions

```markdown
<!-- standards-disable: some-rule -->
```
