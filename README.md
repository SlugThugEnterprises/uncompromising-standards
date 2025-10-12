# Uncompromising Standards

> **Code so good you could trust it with your friend's mom's life.**

Static code quality enforcement for professional developers who refuse to compromise. Fast pattern-based checks with zero tolerance for shortcuts, placeholders, or "I'll fix it later" code.

## Philosophy

Good code isn't optional. When AI generates your code, there's zero excuse for:
- Panic patterns that crash in production
- TODO comments that never get resolved
- Dead code hiding in your codebase
- Debug prints left in production
- Single-letter variables that nobody understands
- 500-line functions that are impossible to maintain

This plugin enforces **damn near perfect code** across multiple languages using fast static checks - no compilation required.

## Languages Supported

Pick the languages you need. Use one, use all:

- ✅ **Rust** - No unwrap/expect/panic, no unsafe without reason
- ✅ **Go** - No nil panics, proper error handling
- ✅ **Python** - No bare excepts, proper exception handling
- ✅ **Ruby** - No bare rescue, proper error handling
- ✅ **JavaScript/TypeScript** - No console.log in production, no any abuse
- ✅ **Bash** - Proper error handling, quoted variables
- ✅ **SQL** - No SELECT *, proper query practices
- ✅ **Markdown** - Quality documentation standards

## Universal Rules (All Languages)

- ❌ No panic/crash patterns without proper handling
- ❌ No TODO/FIXME/HACK/PLACEHOLDER/WIP comments
- ❌ No dead code or unused variables
- ❌ No debug output in production code
- ❌ Files must be ≤200 lines (enforces modularity)
- ❌ Functions must be ≤50 lines (enforces simplicity)
- ❌ No single-letter variables (except i,j,k for loops, x,y,z for math)

## Version 2.0: Mandatory Enforcement Mode 🔒

**NEW in v2.0:** AI agents now have **ZERO CHOICE** - they either pass standards or their code gets blocked/reverted automatically.

### How Mandatory Enforcement Works:

1. **Pre-Write Hook** - Code is validated BEFORE being written to disk
   - If standards violated → Write is BLOCKED
   - AI must fix violations and retry

2. **Post-Write Hook** - Code is validated AFTER being written
   - If standards violated → File is AUTOMATICALLY REVERTED
   - Backup is restored or file is deleted

3. **Auto-Fix Mode** - Common violations are fixed automatically
   - Removes `#[allow(dead_code)]`, `dbg!()`, TODO comments
   - Removes `console.log()`, `print()` statements
   - AI gets one chance to fix before blocking

4. **Pre-Commit Hook** - Final gate before git commit
   - ALL staged files validated
   - Commit BLOCKED if any violations found

### What AI Agents Cannot Do Anymore:

❌ Write code with `.unwrap()` or `.expect()`
❌ Leave TODO/FIXME comments
❌ Hide dead code with `#[allow(...)]`
❌ Use `print()` or `console.log()` in production
❌ Create files >200 lines or functions >50 lines
❌ Skip validation or disable checks

**The code either passes standards or it doesn't get written. Period.**

## Installation

### For Claude Code

Add this plugin marketplace:

```bash
/plugin marketplace add SlugThugEnterprises/uncompromising-standards
```

Then browse and install:

```bash
/plugin
# Select "Browse Plugins" → "uncompromising-standards"
```

Restart Claude Code after installation.

### Standalone Usage

Clone and use the enforcers directly:

```bash
git clone https://github.com/SlugThugEnterprises/uncompromising-standards.git
cd uncompromising-standards

# Check a single file
./checkers/rust-enforcer.sh path/to/file.rs

# Check entire directory recursively
./checkers/rust-enforcer.sh path/to/directory/
```

## Usage

### Claude Code Slash Commands

Once installed, use these commands:

```bash
/check-rust path/to/directory    # Check all Rust files
/check-go path/to/directory      # Check all Go files
/check-python path/to/directory  # Check all Python files
/check-ruby path/to/directory    # Check all Ruby files
/check-js path/to/directory      # Check all JS/TS files
/check-bash path/to/directory    # Check all shell scripts
/check-sql path/to/directory     # Check all SQL files
/check-docs path/to/directory    # Check all Markdown files
/check-all path/to/directory     # Check EVERYTHING
```

### Direct Enforcer Usage

Each enforcer is standalone:

```bash
# Rust
./checkers/rust-enforcer.sh src/

# Python
./checkers/python-enforcer.py app/

# Go
./checkers/go-enforcer.sh cmd/

# All at once
for checker in checkers/*-enforcer.*; do
    $checker .
done
```

## What Gets Caught

### Rust Example

**❌ FAILS:**
```rust
fn process(data: &str) -> String {
    let parsed = serde_json::from_str(data).unwrap();  // ← CRITICAL
    println!("Debug: {:?}", parsed);                    // ← ERROR (not in main.rs)

    #[allow(dead_code)]                                 // ← CRITICAL
    fn helper() { }

    // TODO: handle edge case                           // ← CRITICAL

    parsed.get("key").expect("exists")                  // ← CRITICAL
}
```

**✅ PASSES:**
```rust
fn process(data: &str) -> Result<String, Error> {
    let parsed = serde_json::from_str(data)
        .map_err(|e| Error::Parse(e.to_string()))?;

    tracing::debug!("Processing data");  // Proper logging

    let value = parsed
        .get("key")
        .ok_or(Error::MissingKey)?;

    Ok(value.to_string())
}
```

### Python Example

**❌ FAILS:**
```python
def process(data):
    try:
        result = json.loads(data)
        print(f"Debug: {result}")  # ← ERROR (not in __main__)
    except:                         # ← CRITICAL (bare except)
        pass                        # ← CRITICAL (placeholder)

    # TODO: add validation        # ← CRITICAL
    x = result['key']              # ← WARNING (single letter)
    return x
```

**✅ PASSES:**
```python
def process(data: str) -> dict:
    try:
        result = json.loads(data)
        logger.debug(f"Processing: {result}")  # Proper logging
    except json.JSONDecodeError as error:
        raise ProcessingError(f"Invalid JSON: {error}")

    if 'key' not in result:
        raise KeyError("Missing required key")

    value = result['key']
    return value
```

## Configuration

Customize rules in `config/standards.yaml`:

```yaml
global:
  max_file_lines: 200
  max_function_lines: 50
  allow_single_letter_vars: [i, j, k, x, y, z]

rust:
  enforce_error_handling: true
  ban_unwrap: true
  ban_expect: true
  ban_panic: true

python:
  ban_bare_except: true
  require_type_hints: false
  ban_print: true
```

## CI/CD Integration

### GitHub Actions

```yaml
- name: Enforce Code Standards
  run: |
    git clone https://github.com/SlugThugEnterprises/uncompromising-standards.git
    ./uncompromising-standards/checkers/rust-enforcer.sh src/
    ./uncompromising-standards/checkers/python-enforcer.py app/
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

./checkers/rust-enforcer.sh src/ || exit 1
./checkers/python-enforcer.py app/ || exit 1
echo "✅ Code standards enforced"
```

## Why Static Checks?

**Fast:** Instant feedback, no compilation
**Portable:** Works anywhere, no dependencies
**Language-agnostic:** Same philosophy across all languages
**CI-friendly:** Easy to integrate into any pipeline
**Zero-config:** Works out of the box with sane defaults

## For AI-Generated Code

If AI is writing your code, there's **zero excuse** for quality issues:

- ✅ AI never gets tired - demand perfection every time
- ✅ AI doesn't cut corners - enforce all rules strictly
- ✅ AI can refactor instantly - no "I'll fix later"
- ✅ AI has no ego - fails fast and fixes immediately

This plugin holds AI-generated code to the same standard you'd want for mission-critical systems.

## Contributing

Found a pattern that should be banned? Open a PR!

Each enforcer is standalone, so adding new checks is straightforward:

1. Add pattern to appropriate enforcer
2. Add test case
3. Update docs
4. Submit PR

## License

MIT - Use it, modify it, share it. Just write good code.

## Acknowledgments

Built for developers who believe code quality isn't negotiable.

> "Code so good you could trust it with your friend's mom's life." ™
