#!/usr/bin/env bash
set -euo pipefail

# Post-Write Hook - Validation & Rollback
# Runs AFTER file is written by AI agents
# If check fails, file is AUTOMATICALLY REVERTED
# Shows exact error so you know what to fix

FILE_PATH="$1"
FILE_EXT="${FILE_PATH##*.}"
BACKUP_FILE="${FILE_PATH}.backup"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKERS_DIR="$HOOK_DIR/../checkers"

echo -e "${YELLOW}POST-WRITE VALIDATION: $FILE_PATH${NC}"

# Create backup
if [ -f "$FILE_PATH" ]; then
  cp "$FILE_PATH" "$BACKUP_FILE"
fi

# Route to appropriate enforcer
case "$FILE_EXT" in
  rs)
    ENFORCER="$CHECKERS_DIR/rust-StaticChecker.sh"
    ;;
  go)
    ENFORCER="$CHECKERS_DIR/go-enforcer.sh"
    ;;
  py)
    ENFORCER="$CHECKERS_DIR/python-enforcer.py"
    ;;
  rb)
    ENFORCER="$CHECKERS_DIR/ruby-enforcer.rb"
    ;;
  js|ts|jsx|tsx)
    ENFORCER="$CHECKERS_DIR/javascript-enforcer.js"
    ;;
  sh|bash)
    ENFORCER="$CHECKERS_DIR/bash-enforcer.sh"
    ;;
  sql)
    ENFORCER="$CHECKERS_DIR/sql-enforcer.sh"
    ;;
  md)
    ENFORCER="$CHECKERS_DIR/markdown-enforcer.sh"
    ;;
  *)
    echo -e "${YELLOW}No enforcer for .$FILE_EXT files${NC}"
    rm -f "$BACKUP_FILE"
    exit 0
    ;;
esac

# Run validation
CHECK_OUTPUT=$("$ENFORCER" "$FILE_PATH" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}Validation passed${NC}"
  rm -f "$BACKUP_FILE"
  exit 0
else
  echo "$CHECK_OUTPUT" | grep -A2 "CRITICAL\|ERROR" | head -10
  
  echo -e "${RED}VALIDATION FAILED - REVERTING FILE${NC}"

  # Restore from backup or delete
  if [ -f "$BACKUP_FILE" ]; then
    mv "$BACKUP_FILE" "$FILE_PATH"
    echo -e "${YELLOW}File reverted to previous version${NC}"
  else
    rm -f "$FILE_PATH"
    echo -e "${YELLOW}Invalid file deleted${NC}"
  fi

  echo -e "${RED}Fix the errors and try again${NC}"
  exit 1
fi
