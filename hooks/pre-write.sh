#!/usr/bin/env bash
set -euo pipefail

# Pre-Write Hook - Mandatory Enforcement
# Runs BEFORE any file is written by AI agents
# If check fails, file write is BLOCKED
# Shows exact error so you know what to fix

FILE_PATH="$1"
FILE_EXT="${FILE_PATH##*.}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKERS_DIR="$HOOK_DIR/../checkers"

echo -e "${YELLOW}CHECKING: $FILE_PATH${NC}"

# Route to appropriate enforcer
case "$FILE_EXT" in
  rs)
    CHECK_OUTPUT=$("$CHECKERS_DIR/rust-StaticChecker.sh" "$FILE_PATH" 2>&1)
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
      echo "$CHECK_OUTPUT" | grep -A2 "CRITICAL\|ERROR" | head -10
    fi
    ;;
  go)
    CHECK_OUTPUT=$("$CHECKERS_DIR/go-enforcer.sh" "$FILE_PATH" 2>&1)
    EXIT_CODE=$?
    ;;
  py)
    CHECK_OUTPUT=$("$CHECKERS_DIR/python-enforcer.py" "$FILE_PATH" 2>&1)
    EXIT_CODE=$?
    ;;
  rb)
    CHECK_OUTPUT=$("$CHECKERS_DIR/ruby-enforcer.rb" "$FILE_PATH" 2>&1)
    EXIT_CODE=$?
    ;;
  js|ts|jsx|tsx)
    CHECK_OUTPUT=$("$CHECKERS_DIR/javascript-enforcer.js" "$FILE_PATH" 2>&1)
    EXIT_CODE=$?
    ;;
  sh|bash)
    CHECK_OUTPUT=$("$CHECKERS_DIR/bash-enforcer.sh" "$FILE_PATH" 2>&1)
    EXIT_CODE=$?
    ;;
  sql)
    CHECK_OUTPUT=$("$CHECKERS_DIR/sql-enforcer.sh" "$FILE_PATH" 2>&1)
    EXIT_CODE=$?
    ;;
  md)
    CHECK_OUTPUT=$("$CHECKERS_DIR/markdown-enforcer.sh" "$FILE_PATH" 2>&1)
    EXIT_CODE=$?
    ;;
  *)
    echo -e "${YELLOW}No enforcer for .$FILE_EXT files${NC}"
    EXIT_CODE=0
    ;;
esac

if [ $EXIT_CODE -ne 0 ]; then
  echo -e "${RED}BLOCKED: $FILE_PATH has errors${NC}"
  echo -e "${RED}Fix the issues above and try again${NC}"
  exit 1
fi

echo -e "${GREEN}OK - write allowed${NC}"
exit 0
