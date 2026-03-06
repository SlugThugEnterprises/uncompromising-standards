# LLXPRT.md - Project Context & Standards

**Project Name:** Uncompromising Standards

## Project Overview

This repository contains a **strict pre-write code enforcement system** for AI coding agents (Claude Code / LLxprt Code / similar tools).

Its purpose is to prevent AI agents from generating low-quality, unsafe, or non-idiomatic code by intercepting `Write`/`write_file` operations and running static analysis before the code is saved.

The system is particularly focused on **Rust**, but includes rules for several other languages.

### Core Philosophy
- "Uncompromising" = very strict standards
- Fail-fast on common AI anti-patterns (TODOs, debug prints, unsafe code, long functions/files)
- Enforce high-quality, safe, maintainable code
- Especially strict on Rust (no heap allocation, no `unsafe`, no panics, etc.)

## Directory Structure

```bash
/opt/uncompromising-standards/
├── rules/                    # Language-specific rule documentation
│   ├── RULES.rust.md         # Most comprehensive (primary focus)
│   ├── RULES.bash.md
│   ├── RULES.go.md
│   ├── RULES.javascript.md
│   ├── RULES.python.md
│   └── ...
├── checkers/                 # Executable validation scripts
│   ├── rs.sh                 # Rust checker (very strict, 280+ lines)
│   └── sh.sh                 # Bash checker
├── hooks/
│   └── pre-write.sh          # Main hook called by the AI agent
├── tools/
│   └── check.sh              # Core JSON parsing and orchestration logic
├── docs/                     # Additional documentation
├── .claude/                  # Claude-specific configuration
├── CLAUDE.md                 # Guidance for Claude Code
├── LLXPRT.md                 # This file (LLxprt context)
├── sample.rs                 # Sample Rust file (created during session)
└── install.sh_Ignore         # Installation script (note: renamed)
```

## Key Technologies & Architecture

- **Shell/Bash** — All core tooling is written in Bash
- **jq** — Required for JSON parsing from AI tool calls
- **Pre-write Hook Pattern** — Intercepts AI `Write` tool calls via `~/.claude/settings.json`
- **Fail-open design** — Unknown file types are allowed by default
- **Bypass mechanism** — Files in `hooks/`, `tools/`, `checkers/`, `rules/`, and `.claude/` bypass validation

## Core Rules (Especially for Rust)

From `rules/RULES.rust.md`:

### Forbidden in Rust:
- `unsafe` code in any form
- Heap allocation: `vec!`, `Box`, `HashMap`, `String` (in many contexts), `Vec`, `Arc`, `Rc`
- Panic points: `unwrap()`, `expect()`, `panic!()`, `todo!()`
- Arithmetic operators (`+`, `-`, `*`, `/`) — must use saturating methods
- Array indexing (`arr[i]`) — must use `.get()`
- `println!`, `eprintln!`, `dbg!`
- `clone()` (except when absolutely necessary)
- Files > 200 lines
- Functions > 50 lines
- Any `TODO`, `FIXME`, `HACK`

### Required at crate root:
```rust
#![forbid(unsafe_code)]
```

## Building / Installation

```bash
# Install the hook into Claude Code
./install.sh_Ignore

# Make scripts executable
chmod +x hooks/pre-write.sh tools/check.sh checkers/*.sh
```

After installation, restart your AI coding interface.

The hook will then run automatically before every `write_file` operation.

## Development Workflow

1. AI attempts to write code using `write_file` tool
2. `hooks/pre-write.sh` → `tools/check.sh` receives JSON
3. Appropriate checker (`checkers/rs.sh` for `.rs` files) is invoked
4. If violations found → Write is **blocked** with explanatory error
5. If clean → Write is allowed

## Important Notes for AI Agents (LLxprt)

- **This directory itself** is mostly exempt from checks (bypass list includes `hooks/`, `tools/`, `checkers/`, `rules/`)
- The `sample.rs` file currently **violates many rules** (too long, uses `HashMap`, `println!`, etc.) — it was created as a demonstration only
- When editing Rust code in this project or new projects, you **must** follow the strict rules in `rules/RULES.rust.md`
- Always check `rules/RULES.*.md` for the target language before writing significant code
- Prefer small, focused functions and files

## Preferences (from LLxprt memory)

- Strongly prefer **TypeScript** when language is not specified
- However, in *this* workspace, **Rust with uncompromising standards** takes precedence

---

**Last updated:** March 2026
**Purpose:** This file provides persistent context to LLxprt Code about the project's strict standards and architecture.
