#!/usr/bin/env bash
set -euo pipefail

# Pre-Commit Hook - Final Gate
# Runs before git commit
# Validates ALL staged files

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKERS_DIR="$HOOK_DIR/../checkers"

echo -e "${YELLOW}🛡️  PRE-COMMIT: Validating staged files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FAILED_FILES=()

# Get all staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
  echo -e "${GREEN}✅ No files to check${NC}"
  exit 0
fi

for FILE in $STAGED_FILES; do
  # Skip if file doesn't exist (deleted)
  [ ! -f "$FILE" ] && continue

  EXT="${FILE##*.}"

  case "$EXT" in
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
      continue
      ;;
  esac

  echo "Checking: $FILE"
  if ! "$ENFORCER" "$FILE" > /dev/null 2>&1; then
    FAILED_FILES+=("$FILE")
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ${#FAILED_FILES[@]} -eq 0 ]; then
  echo -e "${GREEN}✅ All staged files pass standards - commit allowed${NC}"
  exit 0
else
  echo -e "${RED}❌ COMMIT BLOCKED: ${#FAILED_FILES[@]} file(s) violate standards${NC}"
  echo ""
  echo -e "${RED}Failed files:${NC}"
  for FILE in "${FAILED_FILES[@]}"; do
    echo "  - $FILE"
  done
  echo ""
  echo -e "${YELLOW}Fix violations and try again${NC}"
  exit 1
fi
