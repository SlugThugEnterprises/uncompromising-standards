# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the "Uncompromising Standards" project - a static code analysis system that enforces strict coding rules before every Write operation. It intercepts Write tool calls and validates content against language-specific rules.

### Core Components

- **Pre-write hook** (`hooks/pre-write.sh`) - Entry point called by Claude Code
- **Core logic** (`tools/check.sh`) - JSON parsing, checker dispatch, exit code handling
- **Language checkers** (`checkers/*.sh`) - Per-language validation scripts:
  - `rs.sh` - Rust (very strict)
  - `py.sh` - Python (uses ruff + custom A+ standards)
  - `sh.sh` - Bash (incomplete)
- **Rules definitions** (`rules/RULES.*.md`) - Documentation of enforced standards
- **LLXPRT.md** - Project context file for LLxprt/Claude Code sessions

### Installation

```bash
# Make scripts executable
chmod +x hooks/pre-write.sh tools/check.sh checkers/*.sh

# Install hook (requires jq)
./install.sh_Ignore

# Verify hook is registered
cat ~/.claude/settings.json | jq '.hooks.PreToolUse'
```

### Running the Checker Manually

```bash
# Verify hook is correctly configured (recommended first step)
./tools/verify-hook.sh

# Test a file against the Rust checker
echo '{"tool_name": "Write", "tool_input": {"file_path": "test.rs", "content": "fn main() { println!(\"test\"); }" }}' | ./tools/check.sh

# Test with a file directly
./checkers/rs.sh /path/to/file.rs

# Test the hook
echo '{"tool": "Write", "tool_input": {"path": "sample.rs", "content": "..."}}' | ./hooks/pre-write.sh
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

## Rust Rules (Most Strict)

The Rust checker (`checkers/rs.sh`) enforces additional restrictions:

- No `unsafe` code (crate root must have `#![forbid(unsafe_code)]`)
- No heap allocation: `vec!`, `Box`, `HashMap`, `String`, `Arc`, `Rc`
- No panic points: `unwrap()`, `expect()`, `panic!()`, `todo!()`
- No arithmetic operators - use saturating methods (`.saturating_add()`)
- No array indexing (`arr[i]`) - use `.get(i)` instead
- No `println!`, `eprintln!`, `dbg!`
- No `.clone()` unless absolutely necessary
- Single-letter vars only: `i`, `j`, `k`, `x`, `y`, `z`

See `rules/RULES.rust.md` for the full list.

## Checker Extension

To add a new language:

1. Create `checkers/<lang>.sh` that accepts a file path as argument
2. Exit 0 on pass, exit 1+ (usually 2) on failure
3. Print `FAIL: <rule-name>   File: <filename>   Line: <n>   Detail: <message>` for violations
4. Add the extension mapping in `tools/check.sh` `get_checker()` function
5. Add rules documentation in `rules/RULES.<lang>.md`

## Current Implementation Status

- **Rust checker** (`checkers/rs.sh`): Fully implemented (~280 lines)
- **Python checker** (`checkers/py.sh`): Uses ruff + custom A+ standards checks
- **Bash checker** (`checkers/sh.sh`): References non-existent files - incomplete
- **Hook**: Functional for both Claude Code and LLxprt formats
