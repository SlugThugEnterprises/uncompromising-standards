#!/usr/bin/env bash
set -euo pipefail

# Pre-Write Hook - Mandatory Enforcement
# Runs BEFORE any file is written by AI agents
# If check fails, file write is BLOCKED

FILE_PATH="$1"
FILE_EXT="${FILE_PATH##*.}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKERS_DIR="$HOOK_DIR/../checkers"

echo -e "${YELLOW}🛡️  ENFORCING STANDARDS: $FILE_PATH${NC}"

# Route to appropriate enforcer
case "$FILE_EXT" in
  rs)
    "$CHECKERS_DIR/rust-enforcer.sh" "$FILE_PATH"
    ;;
  go)
    "$CHECKERS_DIR/go-enforcer.sh" "$FILE_PATH"
    ;;
  py)
    "$CHECKERS_DIR/python-enforcer.py" "$FILE_PATH"
    ;;
  rb)
    "$CHECKERS_DIR/ruby-enforcer.rb" "$FILE_PATH"
    ;;
  js|ts|jsx|tsx)
    "$CHECKERS_DIR/javascript-enforcer.js" "$FILE_PATH"
    ;;
  sh|bash)
    "$CHECKERS_DIR/bash-enforcer.sh" "$FILE_PATH"
    ;;
  sql)
    "$CHECKERS_DIR/sql-enforcer.sh" "$FILE_PATH"
    ;;
  md)
    "$CHECKERS_DIR/markdown-enforcer.sh" "$FILE_PATH"
    ;;
  *)
    echo -e "${YELLOW}⚠️  No enforcer for .$FILE_EXT files${NC}"
    exit 0
    ;;
esac

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo -e "${RED}❌ WRITE BLOCKED: Code violates standards${NC}"
  echo -e "${RED}🚫 File will NOT be written until violations are fixed${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Standards check passed - write allowed${NC}"
exit 0
