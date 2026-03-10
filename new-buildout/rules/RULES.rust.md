# Rust Coding Standards

This project uses uncompromising-standards - a strict safety-focused coding standard.

## Required at Crate Root

```rust
#![forbid(unsafe_code)]
```

## Forbidden Patterns

### No Unsafe / UB
- `unsafe` blocks, `transmute`, `static mut`, `UnsafeCell`

### No Dynamic Allocation
- `vec!`, `Box`, `HashMap`, `Arc`, `Rc` (no heap)

### No Panic Points
- `unwrap()`, `expect()`, `panic!()`, `unreachable!()`
- Bare arithmetic: `+`, `-`, `*`, `/`, `%`
  - Use: `.saturating_add()`, `.saturating_sub()`, etc.
- Direct array indexing: `array[i]`
  - Use: `.get(i)` instead

### No Debug Output
- `println!`, `eprintln!`, `dbg!`

### No Incomplete Code
- `todo!`, `TODO`, `FIXME`, `HACK`, `XXX`, `unimplemented!()`

### No Fallbacks
- `unwrap_or()`, `unwrap_or_else()`, `Default::default()`

### No Unnecessary Copies
- `.clone()` (avoid unless truly needed)

## Naming Rules

- Single-letter vars: only `i`, `j`, `k`, `x`, `y`, `z` allowed
- All other variables need descriptive names

## Size Limits

- Max function length: 50 lines
- Max file length: 200 lines
- Balance: braces `{}`, parens `()`, brackets `[]` must match

## Quick Fixes

| Forbidden | Use Instead |
|-----------|-------------|
| `result.unwrap()` | `?` or `match` |
| `array[i]` | `array.get(i)` |
| `a + b` | `a.saturating_add(b)` |
| `vec![1,2]` | `[1, 2]` (array) |
| `.clone()` | borrow or reference |
| `println!()` | proper logging trait |

## When Blocked

The hook will show:
- What is forbidden (e.g., "unwrap() forbidden")
- Which line
- How to fix it

Read `.claude/Coding-standards` for full rules.
