# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the "Uncompromising Standards" project - a static code analysis system that enforces strict coding rules before every Write operation in Claude Code. It consists of:

1. **Pre-write hook** (`hooks/pre-write.sh`) - Intercepts Write tool calls and validates content against language-specific rules
2. **Language checkers** (`checkers/*.sh`) - Per-language validation scripts
3. **Rules definitions** (`rules/RULES.*.md`) - Documentation of enforced standards

## Architecture

```
/opt/uncompromising-standards/
├── hooks/pre-write.sh       # Main hook entry point
├── tools/checker.sh         # Router - dispatches to language-specific checkers
├── checkers/                # Language-specific checkers
│   ├── sh.sh               # Bash checker (references missing lib/core.sh and modules/)
│   └── rs.sh               # Rust checker (standalone, comprehensive)
└── rules/                   # Rule definitions per language
    ├── RULES.md            # Universal rules
    ├── RULES.python.md
    ├── RULES.javascript.md
    ├── RULES.bash.md
    ├── RULES.go.md
    ├── RULES.rust.md
    ├── RULES.ruby.md
    ├── RULES.sql.md
    └── RULES.markdown.md
```

## Key Behaviors

- **Fail-open**: Unknown file extensions are allowed (no checker = pass)
- **Hook bypass**: Writes to `hooks/`, `tools/`, `checkers/`, `rules/`, `.claude/` directories bypass validation
- **Exceptions**: Rules can be disabled with `# standards-disable: rule-name` or `# noqa: rule-name` comments

## Universal CRITICAL Rules (all languages)

| Rule | Threshold | Action |
|------|-----------|--------|
| File length | >200 lines | Block |
| Function length | >50 lines | Block |
| TODO/FIXME/HACK | Any | Block |
| Secrets | Hardcoded API keys/tokens | Block |
| Debugger statements | `breakpoint()`, `pdb` | Block |

## Installation

Run `./install.sh` to install the pre-write hook. Requires `jq`.

## Current Implementation Status

- **Rust checker** (`checkers/rs.sh`): Fully implemented with strict rules including traceability requirements (`@satisfies REQ-...`), heap allocation bans, operator restrictions, and more
- **Bash checker** (`checkers/sh.sh`): References non-existent `checkers/lib/core.sh` and `checkers/modules/` - appears incomplete
- **Hook**: Functional but relies on missing checker infrastructure for non-Rust languages
