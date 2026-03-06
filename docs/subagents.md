# Subagents

Custom AI agents for specialized tasks.

## Location

- User: `~/.claude/agents/`
- Project: `.claude/agents/`

## File Format

Markdown with YAML frontmatter:

```yaml
---
description: Agent purpose
model: sonnet  # Optional: haiku, sonnet, opus
tools:
  - Read
  - Glob
  - Grep
---

Your agent prompt here.
```

## Usage

```
Use the Agent tool to invoke your subagent.
```
