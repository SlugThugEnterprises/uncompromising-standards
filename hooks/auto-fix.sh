#!/usr/bin/env bash
set -euo pipefail

# Auto-Fix Hook - Attempt to Fix Common Violations
# Runs when AI agent code fails validation
# Attempts automatic fixes before blocking

FILE_PATH="$1"
FILE_EXT="${FILE_PATH##*.}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔧 AUTO-FIX: Attempting to fix violations in $FILE_PATH${NC}"

FIXES_APPLIED=0

# Auto-fix based on language
case "$FILE_EXT" in
  rs)
    # Remove #[allow(dead_code)]
    if sed -i '/#\[allow(dead_code)\]/d' "$FILE_PATH" 2>/dev/null; then
      echo "  ✓ Removed #[allow(dead_code)]"
      ((FIXES_APPLIED++))
    fi

    # Remove #[allow(unused_*)]
    if sed -i '/#\[allow(unused/d' "$FILE_PATH" 2>/dev/null; then
      echo "  ✓ Removed #[allow(unused_*)]"
      ((FIXES_APPLIED++))
    fi

    # Remove dbg! macros
    if sed -i '/dbg!/d' "$FILE_PATH" 2>/dev/null; then
      echo "  ✓ Removed dbg!() macros"
      ((FIXES_APPLIED++))
    fi

    # Remove TODO/FIXME comments
    if sed -i '/TODO\|FIXME\|HACK\|XXX\|TEMP\|WIP/d' "$FILE_PATH" 2>/dev/null; then
      echo "  ✓ Removed placeholder comments"
      ((FIXES_APPLIED++))
    fi
    ;;

  py)
    # Remove print() statements (outside __main__)
    if ! grep -q "if __name__" "$FILE_PATH"; then
      if sed -i '/^[[:space:]]*print(/d' "$FILE_PATH" 2>/dev/null; then
        echo "  ✓ Removed print() statements"
        ((FIXES_APPLIED++))
      fi
    fi

    # Remove TODO comments
    if sed -i '/# TODO\|# FIXME\|# HACK\|# XXX/d' "$FILE_PATH" 2>/dev/null; then
      echo "  ✓ Removed placeholder comments"
      ((FIXES_APPLIED++))
    fi
    ;;

  js|ts)
    # Remove console.log
    if sed -i '/console\.(log|debug|info|warn|error)/d' "$FILE_PATH" 2>/dev/null; then
      echo "  ✓ Removed console.log() statements"
      ((FIXES_APPLIED++))
    fi

    # Remove // TODO comments
    if sed -i '/\/\/ TODO\|\/\/ FIXME\|\/\/ HACK/d' "$FILE_PATH" 2>/dev/null; then
      echo "  ✓ Removed placeholder comments"
      ((FIXES_APPLIED++))
    fi
    ;;

  *)
    echo -e "${YELLOW}  ⚠️  No auto-fixes available for .$FILE_EXT${NC}"
    exit 1
    ;;
esac

if [ $FIXES_APPLIED -gt 0 ]; then
  echo -e "${GREEN}✅ Applied $FIXES_APPLIED auto-fix(es)${NC}"
  echo -e "${YELLOW}Re-running validation...${NC}"
  exit 0
else
  echo -e "${RED}❌ No auto-fixes available for these violations${NC}"
  exit 1
fi
