#!/usr/bin/env bash
# =============================================================================
# Format Checker Output
#
# Takes checker stderr/stdout and formats it into a clean error message.
# =============================================================================

# Read stdin
input=$(cat)

# Extract FAIL lines, clean them up, format nicely
formatted=$(echo "$input" | grep -E 'FAIL' | grep -v 'Check FAILED' | sed 's/.*FAIL.*: //' | sed 's/   File: .*//' | sed 's/\x1b\[[0-9;]*m//g')

if [[ -z "$formatted" ]]; then
    echo "Code standards check failed"
else
    # Replace newlines with semicolons for compact output
    echo "$formatted" | tr '\n' ';' | sed 's/;/; /g' | sed 's/; $//'
fi
