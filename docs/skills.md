# Skills

Custom prompts that can be invoked with `/skill-name`.

## Location

- User skills: `~/.claude/skills/`
- Project skills: `.claude/skills/`

## File Format

Markdown file with YAML frontmatter:

```yaml
---
description: Description shown in /help
parameters:
  - name: arg1
    description: What this argument does
---

Your skill prompt here.
Use {{args.arg1}} for parameters.
```

## Usage

```
/skill-name
/skill-name arg1 value
```

## Auto-loading

Skills can auto-load based on context using `when` in frontmatter:

```yaml
---
when: file.path matches "*.rs"
---
This skill loads when editing Rust files.
```
