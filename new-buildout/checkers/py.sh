#!/usr/bin/env python3
"""
Python A+ Code Checker

Static analysis - checks issues the AI can fix in its proposed content.
"""

import subprocess
import sys
import re
import os
from typing import List, Tuple

# ANSI colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
NC = "\033[0m"  # No Color

# Rules configuration
MAX_FILE_LINES = 300
MAX_FUNCTION_LINES = 50
MAX_PARAMS = 5

# Forbidden patterns (rule_name, regex, message)
FORBIDDEN_PATTERNS = [
    ("todo", r"\b(TODO|FIXME|HACK|XXX|TEMP|WIP|PLACEHOLDER)\b", "Incomplete code marker"),
    ("bare_except", r"\bexcept\s*:", "Bare except found"),
    ("silent_failure", r"except\s+.*?:\s*\n\s*pass", "Silent failure (except + pass)"),
    ("print_in_code", r"\bprint\s*\(", "print() in code (use logging)"),
    ("debug_breakpoint", r"\b(breakpoint|pdb\.set_trace)\s*\(", "Debug statement"),
    ("secret", r"(api[_-]?key|password|token|secret[_-]?key)\s*=\s*[\"']", "Hardcoded secret"),
    ("exec_usage", r"\bexec\s*\(", "exec() usage"),
    ("eval_usage", r"\beval\s*\(", "eval() usage"),
    ("import_wildcard", r"from\s+\w+\s+import\s+\*", "Wildcard import"),
    ("compare_none", r"==\s*None|is\s+not\s+None", "Compare to None (use 'is None')"),
    ("magic_number", r"\b\d{3,}\b", "Magic number (use named constant)"),
    ("os_chdir", r"os\.chdir\s*\(", "os.chdir() usage"),
]

# Bad variable names
BAD_NAMES = {"data", "thing", "stuff", "obj", "temp", "do", "handle", "process"}
ALLOWED_SINGLE_LETTER = {"i", "j", "k", "x", "y", "z"}


def check_file(file_path: str) -> List[Tuple[str, int, str]]:
    """Check a Python file for A+ standards violations."""
    errors = []

    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return errors

    with open(file_path, "r") as f:
        lines = f.readlines()

    # Check file length
    if len(lines) > MAX_FILE_LINES:
        errors.append(("file-length", 0, f"File exceeds {MAX_FILE_LINES} lines ({len(lines)} lines)"))

    # Track function definitions and their line counts
    in_function = False
    function_start = 0
    function_name = ""
    function_indent = 0

    # Track decorator context
    has_forbid_unsafe = False

    for i, line in enumerate(lines, 1):
        stripped = line.strip()

        # Check for standards-disable comments (skip rest of checks for this line/file if needed)
        if "standards-disable" in stripped or "noqa" in stripped:
            continue

        # Check forbidden patterns
        for rule_name, pattern, message in FORBIDDEN_PATTERNS:
            if re.search(pattern, stripped, re.IGNORECASE):
                # Skip if in test file or __main__
                if rule_name in ("print_in_code",) and ("test" in file_path or "__main__" in stripped):
                    continue
                if rule_name == "magic_number":
                    # Allow if it's in a test or assignment to constant
                    if "test" in file_path or re.match(r"^\s*[A-Z_]+\s*=\s*\d", stripped):
                        continue
                errors.append((rule_name, i, message))

        # Check for missing type hints on public functions
        if re.match(r"^def\s+(\w+)\s*\(", stripped):
            func_name = re.match(r"^def\s+(\w+)", stripped).group(1)
            # Skip private functions (starting with _) and dunder methods
            if not func_name.startswith("_") or func_name in ("__init__", "__call__"):
                # Check if has return type
                if "->" not in stripped:
                    # Only check if it's not a stub
                    if "..." not in stripped:
                        errors.append(("missing_return_type", i, f"Function '{func_name}' missing return type"))

                # Check for missing parameter type hints (simple check for single-line defs)
                # Extract parameter section: def name(params) -> ret:
                param_match = re.search(r'def\s+\w+\s*\(([^)]*)\)', stripped)
                if param_match:
                    params_str = param_match.group(1)
                    # Skip self and empty parameter lists
                    params_str = re.sub(r'\bself\b,?\s*', '', params_str)
                    params_str = params_str.strip()
                    if params_str:
                        # Check if any parameter lacks type hint (no : type pattern)
                        for param in params_str.split(','):
                            param = param.strip()
                            if param and '=' in param:
                                # Has default value, check if typed before =
                                name = param.split('=')[0].strip()
                                if ':' not in name:
                                    # Find what type of param this is
                                    errors.append(("missing_param_type", i, f"Function '{func_name}' parameter '{name}' missing type hint"))
                            elif param and ':' not in param:
                                # Plain parameter without type hint or default
                                errors.append(("missing_param_type", i, f"Function '{func_name}' parameter '{param}' missing type hint"))

        # Track function start/end for length checking
        if re.match(r"^def\s+", stripped) or re.match(r"^async\s+def\s+", stripped):
            # Close previous function
            if in_function and function_start > 0:
                func_lines = i - function_start
                if func_lines > MAX_FUNCTION_LINES:
                    errors.append(("function-length", function_start, f"Function '{function_name}' exceeds {MAX_FUNCTION_LINES} lines ({func_lines} lines)"))

            # Start new function
            in_function = True
            function_start = i
            match = re.match(r"^(\s*)def\s+(\w+)", stripped)
            if match:
                function_name = match.group(2)
                function_indent = len(match.group(1))

        # Check parameter count
        if in_function and re.match(r"^def\s+", stripped):
            # Extract parameters
            match = re.match(r"^def\s+\w+\s*\((.*?)\)", stripped)
            if match:
                params = match.group(1)
                param_list = [p.strip() for p in params.split(",") if p.strip() and p.strip() != "self"]
                if len(param_list) > MAX_PARAMS:
                    errors.append(("excessive_params", i, f"Function has {len(param_list)} parameters (max {MAX_PARAMS})"))

        # Check variable names (only in function scope)
        if in_function:
            # Find assignments
            for match in re.finditer(r"\b([a-z_][a-z0-9_]*)\s*=", stripped):
                var_name = match.group(1)
                if len(var_name) == 1 and var_name not in ALLOWED_SINGLE_LETTER:
                    errors.append(("single_letter_var", i, f"Single-letter variable '{var_name}'"))
                if var_name in BAD_NAMES:
                    errors.append(("bad_name", i, f"Bad variable name '{var_name}'"))

        # Reset function tracking on dedent
        if in_function and stripped and not stripped.startswith("#"):
            current_indent = len(line) - len(line.lstrip())
            if current_indent <= function_indent and not stripped.startswith("def "):
                # End of function
                func_lines = i - function_start
                if func_lines > MAX_FUNCTION_LINES and function_start > 0:
                    errors.append(("function-length", function_start, f"Function '{function_name}' exceeds {MAX_FUNCTION_LINES} lines"))
                in_function = False
                function_start = 0

    # Close last function if still open
    if in_function and function_start > 0:
        func_lines = len(lines) - function_start + 1
        if func_lines > MAX_FUNCTION_LINES:
            errors.append(("function-length", function_start, f"Function '{function_name}' exceeds {MAX_FUNCTION_LINES} lines"))

    return errors


def run_ruff(file_path: str) -> List[Tuple[str, int, str]]:
    """Run ruff linter - returns specific issues the AI can fix."""
    errors = []

    try:
        result = subprocess.run(
            ["ruff", "check", file_path, "--output-format=concise"],
            capture_output=True,
            text=True,
            timeout=30
        )

        for line in result.stdout.splitlines():
            if not line.strip():
                continue
            match = re.match(r".*?:(\d+):.*?:\s*(E\d+|F\d+|W\d+)\s+(.*)", line)
            if match:
                errors.append((match.group(2).lower(), int(match.group(1)), match.group(3)))

    except FileNotFoundError:
        # Ruff not installed - fail hard
        print(f"{RED}ERROR: ruff not installed, cannot run lint checks{NC}", file=sys.stderr)
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print(f"{RED}ERROR: ruff check timed out after 30 seconds{NC}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        # Log error and fail
        print(f"{RED}ERROR: ruff check failed: {e}{NC}", file=sys.stderr)
        sys.exit(1)

    return errors


def run_ruff_format(file_path: str) -> List[Tuple[str, int, str]]:
    """Run ruff format check - tells AI if content needs formatting."""
    errors = []

    try:
        result = subprocess.run(
            ["ruff", "format", "--check", file_path],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode != 0:
            errors.append(("format", 0, "File not formatted (AI should format content before writing)"))
    except FileNotFoundError:
        # Ruff not installed - fail hard
        print(f"{RED}ERROR: ruff not installed, cannot run format checks{NC}", file=sys.stderr)
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print(f"{RED}ERROR: ruff format timed out after 10 seconds{NC}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        # Log error and fail
        print(f"{RED}ERROR: ruff format check failed: {e}{NC}", file=sys.stderr)
        sys.exit(1)

    return errors


def main():
    if len(sys.argv) < 2:
        print("Usage: py.sh <file.py>")
        sys.exit(1)

    file_path = sys.argv[1]

    if not os.path.exists(file_path):
        print(f"{RED}FAIL{NC}: File not found: {file_path}")
        sys.exit(1)

    all_errors = []

    # Run custom A+ standards checks
    custom_errors = check_file(file_path)
    all_errors.extend(custom_errors)

    # Run ruff linter (specific issues AI can fix)
    ruff_errors = run_ruff(file_path)
    all_errors.extend(ruff_errors)

    # Run ruff format check
    format_errors = run_ruff_format(file_path)
    all_errors.extend(format_errors)

    # Report results
    if all_errors:
        print(f"{RED}FAIL{NC}: Python A+ standards check failed")
        for rule, line, message in sorted(all_errors, key=lambda x: x[1]):
            if line > 0:
                print(f"   FAIL: {rule}   File: {file_path}   Line: {line}   Detail: {message}")
            else:
                print(f"   FAIL: {rule}   File: {file_path}   Detail: {message}")
        sys.exit(2)
    else:
        print(f"{GREEN}PASS{NC}: Python A+ standards check passed")
        sys.exit(0)


if __name__ == "__main__":
    main()
