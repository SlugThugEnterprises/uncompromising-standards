#!/usr/bin/env python3
"""
Python Code Enforcer - Uncompromising Standards
"Code so good you could trust it with your friend's mom's life"
"""

import re
import sys
from pathlib import Path

# Colors
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
GREEN = '\033[0;32m'
NC = '\033[0m'

critical = 0
errors = 0
warnings = 0

# Critical patterns
CRITICAL_PATTERNS = {
    'bare_except': r'except\s*:',
    'todo': r'(TODO|FIXME|HACK|XXX|TEMP|WIP|PLACEHOLDER)',
    'pass_placeholder': r'^\s*pass\s*$',
    'debug_breakpoint': r'(breakpoint\(|pdb\.set_trace|import pdb)',
}

# Error patterns
ERROR_PATTERNS = {
    'print_not_main': r'\bprint\(',
}

def check_file(file_path):
    global critical, errors, warnings

    if not Path(file_path).exists():
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    with open(file_path, 'r') as f:
        lines = f.readlines()

    print(f"🔍 Checking Python file: {file_path}")
    print("━" * 60)

    # Check file length
    if len(lines) > 200:
        print(f"{RED}🚨 CRITICAL{NC}: File exceeds 200 lines")
        print(f"   File: {file_path}")
        print(f"   Lines: {len(lines)} (limit: 200)")
        critical += 1

    # Check patterns
    for name, pattern in CRITICAL_PATTERNS.items():
        matches = []
        for i, line in enumerate(lines, 1):
            if re.search(pattern, line):
                matches.append(i)

        if matches:
            print(f"{RED}🚨 CRITICAL{NC}: No {name} allowed")
            print(f"   File: {file_path}")
            print(f"   Lines: {','.join(map(str, matches))}")
            critical += 1

    # Check print() outside __main__ and tests
    is_main = '__main__' in ''.join(lines)
    is_test = '_test.py' in file_path or 'test_' in Path(file_path).name

    if not is_main and not is_test:
        print_lines = []
        for i, line in enumerate(lines, 1):
            if re.search(r'\bprint\(', line):
                print_lines.append(i)

        if print_lines:
            print(f"{RED}❌ ERROR{NC}: print() should only be in __main__ or tests")
            print(f"   File: {file_path}")
            print(f"   Lines: {','.join(map(str, print_lines))}")
            print(f"   Use proper logging (logging module)")
            errors += 1

    # Check for single-letter variables
    single_letter_vars = []
    for i, line in enumerate(lines, 1):
        match = re.search(r'^\s*([a-hln-wA-Z])\s*=', line)
        if match:
            single_letter_vars.append(i)

    if single_letter_vars:
        print(f"{YELLOW}⚠️  WARNING{NC}: Single-letter variable names detected")
        print(f"   File: {file_path}")
        print(f"   Lines: {','.join(map(str, single_letter_vars))}")
        warnings += 1

    # Check function length
    in_function = False
    fn_start = 0
    indent_level = 0

    for i, line in enumerate(lines, 1):
        if re.match(r'^\s*def\s+[a-zA-Z_]', line):
            in_function = True
            fn_start = i
            indent_level = len(line) - len(line.lstrip())
        elif in_function:
            current_indent = len(line) - len(line.lstrip())
            if current_indent <= indent_level and line.strip():
                fn_length = i - fn_start
                if fn_length > 50:
                    print(f"{RED}🚨 CRITICAL{NC}: Function too long: line {fn_start}, length {fn_length} lines")
                    print(f"   File: {file_path}")
                    print(f"   Limit: 50 lines per function")
                    critical += 1
                in_function = False

    print("━" * 60)
    print(f"📊 Summary:")
    print(f"   🚨 Critical: {critical}")
    print(f"   ❌ Errors: {errors}")
    print(f"   ⚠️  Warnings: {warnings}")

    if critical > 0:
        print(f"{RED}❌ Check FAILED - fix critical issues{NC}")
        return 1
    else:
        print(f"{GREEN}✅ Check passed!{NC}")
        return 0

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python-enforcer.py <file.py>")
        sys.exit(1)

    exit_code = check_file(sys.argv[1])
    sys.exit(exit_code)
