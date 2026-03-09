# Python A+ Coding Standard

This project enforces strict Python quality rules based on the A+ Coding Standard.

## Non-Negotiable Rules

| Rule | Description | How to Fix |
|------|-------------|------------|
| `file-length` | File exceeds 300 lines | Split into modules |
| `function-length` | Function exceeds 50 lines | Refactor into smaller functions |
| `todo` | TODO/FIXME/HACK/XXX/TEMP/WIP/PLACEHOLDER | Complete the code or remove comment |
| `bare_except` | Bare `except:` found | Use `except SpecificException:` |
| `silent_failure` | `except: pass` or `except Exception: pass` | Handle the exception properly |
| `secret_*` | Hardcoded API key/password/token/secret | Use env vars or secrets manager |
| `print_in_code` | `print()` in business logic | Use `logging` module |
| `debug_breakpoint` | `breakpoint()`, `pdb.set_trace()` | Remove before committing |

## Type Safety

| Rule | Description | How to Fix |
|------|-------------|------------|
| `missing_return_type` | Public function missing return type | Add `-> Type` annotation |
| `missing_param_type` | Public function missing parameter type | Add `: Type` annotations |
| `any_type` | Using `Any` type | Use specific types |

## Function Rules

| Rule | Description | How to Fix |
|------|-------------|------------|
| `excessive_params` | More than 5 parameters | Use dataclass or split function |
| `nested_loops` | Deeply nested loops (3+) | Extract to separate function |

## Style Rules

| Rule | Description | How to Fix |
|------|-------------|------------|
| `single_letter_var` | Single-letter variable (except i,j,k,x,y,z) | Use descriptive name |
| `bad_name` | Ambiguous name (data, thing, stuff, obj, temp) | Use descriptive name |
| `magic_number` | Magic number without explanation | Extract to named constant |
| `compare_none` | Using `== None` instead of `is None` | Use `is None` |

## Error Handling

```python
# Good
try:
    result = client.lookup(address)
except TimeoutError as exc:
    raise AddressLookupError("Address lookup timed out") from exc

# Bad
try:
    result = client.lookup(address)
except:
    pass
```

## Naming Conventions

- **Nouns for data**: `user`, `invoice`, `total_amount`
- **Verbs for actions**: `get_user()`, `calculate_total()`
- **Booleans**: `is_valid`, `has_access`, `can_retry`
- **Allowed single-letter**: `i`, `j`, `k` for loops only
- **Forbidden**: `data`, `thing`, `stuff`, `obj`, `temp`, `do`, `handle`

## Project Structure

```
project/
  pyproject.toml
  src/project_name/
    __init__.py
    config.py
    models.py
    services/
    repositories/
  tests/
    unit/
    integration/
```

## Quality Gate

Run these before committing (use `ruff` for speed):

```bash
# Fast: format + lint (replaces black + flake8)
ruff format --check .
ruff check .

# Tests
pytest

# Manual (too slow for pre-commit): mypy --strict
```

**Note**: `ruff format` is a 30-100x faster drop-in replacement for Black.

## Exceptions

```python
# standards-disable: file-length, function-length
# noqa: some-rule
```
